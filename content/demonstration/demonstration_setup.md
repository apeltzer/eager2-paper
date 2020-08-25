# nf-core/eager paper - demonstration

This document describes the set up of the pipeline runs used to demonstrate the
additional functionality of nf-core/eager, primarily running metagenomic
screening for pathogens alongside running human DNA screening. This is run on an
institutional server at MPI-SHH due to the requirements of large servers for
screening via MALT (>756 GB memory)

Here we will attempt to reanalyse the 'manual' pathogen screening  in Andrades
Valtueña et al. 2017 and retrieve human biological metadata of the samples from
Andrades Valtueña et al. (that were reported in various other papers) but in a
single nf-core/eager run.

## Environment

The environment this analysis was run on was on a cluster of multiple nodes
running Ubuntu 18.04.4 LTS (kernal v4.15.0-24-generic) with Intel(R) Xeon(R) CPU
E5 series CPUs. The cluster has a SLURM scheduling system, with the
nf-core/eager config files avaliable in the nf-core configs central repository:
https://github.com/nf-core/configs/blob/master/conf/shh.config (for standard
profiles) and
https://github.com/nf-core/configs/blob/master/conf/pipeline/eager/shh.config
(for pipeline specific parameters). 

This analysis further uses singularity version XXX, nextflow verison version
20.04.1 (build 5335)
,
nf-core/eager version 2.2.0dev commit e8906c128c

## Set up

Andrades Valtueña et al. originally took shotgun human data from a range of
human population-genetics papers, and mapped directly to the _Yersinia pestis_
genome. The pestis postive samples are those below in the following list.

Due to the depth of very deep sequencing across many of the samples, we will
only focus here on two samples: KunilaII and Post6 (representing reasonably
sequenced samples), representing samples from two sites.

| Sample   | Pop-Gen Reference              | Bio. Sex | Human On-Target (%) | Mean Fragment Length |
|----------|--------------------------------|----------|---------------------|----------------------|
| KunilaII | Mittnik et al. 2017 Nat Comms. | XY Endo: | 14.81               | 49.8                 |
| Post6    | Knipper et al. 2017 PNAS        | XY       | 57.16               | 39.7                 |

These samples represent different seuqencing strategies including multiple
libraries (KunilaII, UDG and non-UDG), and also sequencing across multiple
chemsitries and lanes (6Post). The associated library metadata is avaliable
using the benchmarking_pathogenscreening profile that comes with nf-core/eager,
and the TSV can be accessed here:
https://github.com/nf-core/test-datasets/blob/eager/testdata/Benchmarking/benchmarking_pathogenscreening.tsv

For human processing, we will follow as close as possible to settings used in
the original two Human papers e.g. the default settings in EAGER other than the
BWA `-l` parameter.

We will use the metagenome screening database reported in the original HOPS
publication ("In our study, HOPS uses a database containing all complete
prokaryotic reference genomes obtained from NCBI (December 1, 2016) with entries
containing “multi” and “uncultured” removed (13 entries). In total, 6249
reference genomes are included in the database, including all major bacterial
pathogens scrutinized here." - Hübler et al. 2019), and use the default pathogen
screening list (including Yersinia pestis) and parameters, as supplied on the
HOPS repository
(https://github.com/rhuebler/HOPS/blob/external/Resources/default_list.txt,
Zenodo: https://doi.org/10.5281/zenodo.3362248)

## Running

The profile 'benchamrking_pathogescreening' contains the following parameters:

```
  //Input data
  input = 'https://raw.githubusercontent.com/nf-core/test-datasets/eager/testdata/AWS/awsmegatests_pathogenscreening.tsv'
  // Genome references
  fasta = 'https://hgdownload.soe.ucsc.edu/goldenPath/hg19/bigZips/hg19.fa.gz'

  complexity_filter_poly_g = true
  mapper = 'bwaaln'
  bwaalnn = 0.01
  bwaalnk = 2
  bwaalnl = 10000
  run_bam_filtering = true
  bam_discard_unmapped = true
  bam_unmapped_type = 'fastq'
  dedupper = 'markduplicates'
  run_mtnucratio = true
  run_sexdeterrmine = true
  run_nuclear_contamination = true
  sexdeterrmine_bedfile = 'https://github.com/nf-core/test-datasets/raw/eager/reference/Human/1240K.pos.list_hs37d5.0based.bed.gz'
  run_nuclear_contamination = true
  run_metagenomic_screening = true
  metagenomic_tool = 'malt'
  run_maltextract = true
  percent_identity = 90
  malt_top_percent = 1
  malt_min_support_mode = 'reads'
  metagenomic_min_support_reads = 1
  malt_max_queries = 100
  malt_memory_mode = 'load'
  maltextract_taxon_list = 'https://raw.githubusercontent.com/rhuebler/HOPS/external/Resources/default_list.txt'
  maltextract_filter = 'def_anc'
  maltextract_toppercent = 0.01
  maltextract_destackingoff = false
  maltextract_downsamplingoff = false
  maltextract_duplicateremovaloff = false
  maltextract_matches = false
  maltextract_megansummary = true
  maltextract_percentidentity = 90.0
  maltextract_topalignment =  false
```

The final command is as follows (using default settings, unless otherwise
stated).

```bash
nextflow run nf-core/eager -r dev \
-profile benchmarking_pathogenscreening,sdag,shh \
--input '/projects1/users/fellows/nextflow/eager2/publication/benchmarking_pathogen/benchmarking_pathogenscreening.tsv' \
--outdir 'results/' \
-w 'work/' \
-name 'nfcoreeager_bench_patho' \
--email 'fellows@shh.mpg.de' \
--database '/projects1/malt/databases/indexed/index038/full-bac-genomes_2016-12' \
--maltextract_ncbifiles '/projects1/clusterhomes/huebler/RMASifter/RMA_Extractor_Resources/' \
-with-tower
```

Note we use MarkDuplicates as DeDup (originally reported in the Mittnik/Knipper
et al. papers) was incorrectly applied as this includes singlend-end data. We
also use a 1240k bed file to speed up sex determination as, while not originally
used on the shotgun data in the Mittnik and Knipper papers, they later generate
enriched data using the 1240k SNP panel.