# nf-core/eager paper - benchmarking

This document describes the set up of server environment used to benchmark
nf-core/eager against two other popular aDNA NGS pipelines: EAGER vs. Paleomix.

The server environment was constructed on a node instance of the GWDG cloud
server. The server OS was set to Ubuntu 18.04.

## Server setup

### Preparation

Ensure everything is up-to-date

```bash
sudo apt update
sudo apt upgrade
sudo apt autoremove
```

Check X11 forwarding is available

```bash
sudo apt install x11-apps
xeyes
```

### nf-core/eager

Install Java

```bash
## Java
sudo apt install openjdk-11-jdk
```

Now install Nextflow and do a little bit of housekeeping

```bash
## Nextflow
mkdir bin && cd !$
curl -s https://get.nextflow.io | bash

# Put nextflow in PATH, not necessary but :shrug:
echo 'PATH=$PATH:/home/cloud/bin/' > ~/.bashrc
source ~/.bashrc

## Run test
nextflow run hello
```

Should see the following 

```txt
N E X T F L O W  ~  version 20.04.1
Pulling nextflow-io/hello ...
downloaded from https://github.com/nextflow-io/hello.git
Launching `nextflow-io/hello` [distracted_torvalds] - revision: ef60d89ab9 [master]
WARN: The use of `echo` method is deprecated
executor >  local (4)
[d6/104882] process > sayHello (2) [100%] 4 of 4 ✔
Ciao world!

Hola world!

Bonjour world!

Hello world!
```

We will use Singularity as our container system, as this is supported by
both nf-core/eager and EAGER v1. This requires a little more setup over conda,
but it is more robust.

```bash
cd ~
## Singularity Dependencies
sudo apt-get update && sudo apt-get install -y \
    build-essential \
    libssl-dev \
    uuid-dev \
    libgpgme11-dev \
    squashfs-tools \
    libseccomp-dev \
    wget \
    pkg-config \
    git \
    cryptsetup

## Install Go
curl -O https://dl.google.com/go/go1.14.4.linux-amd64.tar.gz
tar xvf go1.14.4.linux-amd64.tar.gz
sudo chown -R root:root ./go
sudo mv go /usr/local
echo 'export GOPATH=$HOME/work
export PATH=$PATH:/usr/local/go/bin:$GOPATH/bin' >> ~/.bashrc
 source ~/.bashrc
rm go1.14.4.linux-amd64.tar.gz

# Singularity itself
export VERSION=3.5.2 && # adjust this as necessary \
    wget https://github.com/sylabs/singularity/releases/download/v${VERSION}/singularity-${VERSION}.tar.gz && \
    tar -xzf singularity-${VERSION}.tar.gz && \
    cd singularity

    ./mconfig && \
    make -C builddir && \
    sudo make -C builddir install

cd ~
rm singularity-3.5.2.tar.gz
mv singularity/ bin/

## Now we will set up a singularity cache so all containers are in the same
## place
mkdir -p .singularity/cache

echo 'export NXF_SINGULARITY_CACHEDIR=/home/cloud/.singularity/cache/nxf-cache' >> ~/.bashrc
source ~/.bashrc
```

Now we can test that nf-core/eager will run. Note the testing version is
2.2.0dev, in the `dev` revision/version.

```bash
## get nf-core/eager
mkdir nfcore-eager_test
cd !$
nextflow pull nf-core/eager -r dev
nextflow run nf-core/eager -r dev -profile test_tsv,singularity
cd ~

```

### PALEOMIX

The [documentation](https://paleomix.readthedocs.io/en/latest/) for PALEOMIX
was a little confusing, so this required a bit of back and forth. For safety
I resorted to using a conda environment rather than the `virtualenv` thing, as
it does a similar thing but I can also contain all the additional software
dependencies.

The virtual env thing doesn't actually include all the software, as I
erroneously thought first time around. Lets try conda instead. Will use 2.7
as all of PALAEOMIX is in Python2.

Firstly install conda and set up so it can use bioconda, where most of the 
bioinformatics tools are derived from.

```bash
cd ~/bin
wget https://repo.anaconda.com/miniconda/Miniconda2-latest-Linux-x86_64.sh
chmod +x Miniconda2-latest-Linux-x86_64.sh
./Miniconda2-latest-Linux-x86_64.sh

## Follow instructions, install under /home/cloud/bin/miniconda2
## Do run init
~/bin/miniconda2/bin/conda config --set auto_activate_base false

## Log out and back in again

conda config --add channels defaults
conda config --add channels bioconda
conda config --add channels conda-forge
```

Now we can create an environment specifically for PALAEOMIX (postscript: 
to speed this up I've added an `paleomix_environment.yaml` file than you can
then use instead with `conda env create -f paleomix_environment.yaml`)

```bash
# Make conda environment; note adding missing GATK and R requirement(s) not in docs: https://github.com/MikkelSchubert/paleomix/issues/28
conda create -n paleomix python=2.7 pip adapterremoval=2.3.1 samtools=1.9 picard=2.22.9 bowtie2=2.3.5.1 bwa=0.7.17 mapdamage2=2.0.9 gatk=3.8 r-base=3.5.1 r-rcpp=1.0.4.6 r-rcppgsl=0.3.7 r-gam=1.16.1 r-inline=0.3.15

conda activate paleomix

## While in the paleomix environment, install paleomix
pip install --user paleomix

## For safety add ~/.local/bin to path
echo 'export PATH=$PATH:/home/cloud/.local/bin' >> ~/.bashrc
source ~/.bashrc

conda activate paleomix
```

Ok now we have some hardcoded dependencies to fix..
Firstly we need to get the GATK JAR, because it isn't actually allowed to be
shipped in the bioconda GATK bioconda recipe because of licensing. We can then
symlink this into the ugly folder PALEOMIX wants for the test (at least). We
can also symlink the picard JAR that came with the bioconda environment.

```bash
wget https://storage.googleapis.com/gatk-software/package-archive/gatk/GenomeAnalysisTK-3.8-1-0-gf15c1c3ef.tar.bz2
gatk3-register GenomeAnalysisTK-3.8-1-0-gf15c1c3ef.tar.bz2
mkdir -p /home/cloud/install/jar_root/
ln -s /home/cloud/bin/miniconda2/envs/paleomix/opt/gatk-3.8/GenomeAnalysisTK.jar /home/cloud/install/jar_root/
ln -s /home/cloud/bin/miniconda2/envs/paleomix/share/picard-2.22.9-0/picard.jar /home/cloud/install/jar_root/
rm ~/Genome*.tar.bz2
```

Now we can test that paleomix is working properly.

```bash
cd ~
paleomix bam_pipeline example .
cd ~/bam_pipeline
paleomix bam_pipeline run 000_makefile.yaml

```

As I'm not familar with paleomix, lets try a real-life test, following the 
documentation.

```bash
paleomix bam_pipeline run --write-config
```

### EAGER

Now finally we can set up EAGER v1.

Get the singularity image

```bash
mkdir -p ~/.singularity/cache/EAGER-cache
singularity pull shub://apeltzer/EAGER-GUI

## Test loading
mkdir -p ~/EAGER-test
cd !$

## Download mini test data also used for nf-core/eager
mkdir reference output input/JK2782
wget https://github.com/nf-core/test-datasets/raw/eager/testdata/Mammoth/fastq/JK2782_TGGCCGATCAACGA_L008_{R1,R2}_001.fastq.gz.tengrand.fq.gz
mv *gz input/JK2782
wget https://raw.githubusercontent.com/nf-core/test-datasets/eager/reference/Mammoth/Mammoth_MT_Krause.fna
mv *fna reference


singularity exec -B .:/data ~/.singularity/cache/EAGER-cache/EAGER-GUI_latest.sif eager

## See output/JK2782 for XML file, set mostly on defaults

## To actually run EAGER
singularity exec -B .:/data ~/.singularity/cache/EAGER-cache/EAGER-GUI_latest.sif eagercli /data

```


### Versions

```bash
# Kernal
uname -r
4.15.0-91-generic


lsb_release -a
No LSB modules are available.
Distributor ID:	Ubuntu
Description:	Ubuntu 18.04.4 LTS
Release:	18.04
Codename:	bionic


docker version
Client:
 Version:           19.03.6
 API version:       1.40
 Go version:        go1.12.17
 Git commit:        369ce74a3c
 Built:             Fri Feb 28 23:45:43 2020
 OS/Arch:           linux/amd64
 Experimental:      false

java -version
openjdk version "11.0.7" 2020-04-14
OpenJDK Runtime Environment (build 11.0.7+10-post-Ubuntu-2ubuntu218.04)
OpenJDK 64-Bit Server VM (build 11.0.7+10-post-Ubuntu-2ubuntu218.04, mixed mode, sharing)

nextflow -version

      N E X T F L O W
      version 20.04.1 build 5335
      created 03-05-2020 19:37 UTC (21:37 CEST)
      cite doi:10.1038/nbt.3820
      http://nextflow.io

python --version
Python 2.7.17

pip --version
pip 9.0.1 from /usr/lib/python2.7/dist-packages (python 2.7)

virtualenv --version
virtualenv 20.0.21 from /home/cloud/.local/lib/python2.7/site-packages/virtualenv/__init__.pyc

paleomix
PALEOMIX - pipelines and tools for NGS data analyses.
Version: 1.2.14

singularity --version
singularity version 3.5.2



```