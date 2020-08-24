library(tidyverse)
library(knitr)

sessionInfo()

## Load aggregated runtimes



## Cleanup

results_clean <- results %>%
  separate(col = Run, sep = ":", c("File", "Line", "Category")) %>%
  select(-Line) %>%
  mutate(
    File = str_remove(File, "time_") %>%
      str_remove(".log") %>%
      str_remove("runtimes/") %>%
      str_replace("nf-core_eager", "nf-core/eager") %>%
      str_replace("paleomix_optimised", "paleomix-optimised"),
    Runtime_Minutes = map(Runtime, ~ str_split(.x, "m") %>%
      unlist() %>%
      unlist() %>%
      pluck(1)) %>% unlist() %>% as.numeric()
  ) %>%
  separate(File, sep = "_", into = c("Pipeline", "Replicate")) %>%
  select(-Runtime) %>%
  filter(Replicate != 1)

## Summarise

results_final_tidy <- results_clean %>%
  group_by(Pipeline, Category) %>%
  summarise(
    Mean = round(mean(Runtime_Minutes), digits = 1),
    SD = round(sd(Runtime_Minutes), digits = 1)
  ) %>%
  arrange(Category, Mean)

results_final_print <- results_final_tidy %>%
  unite(col = "Mean Runtime", Mean, SD, sep = " ± ") %>%
  pivot_wider(names_from = Category, values_from = `Mean Runtime`) %>%
  kable()

results_final_print
