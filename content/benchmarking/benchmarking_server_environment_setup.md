# nf-core/eager paper - benchmarking

This document describes the set up of server environment used to benchmark
nf-core/eager vs EAGER and Paleomix, two alternative aDNA NGS pipelines.

The server environment was constructed on a node instance of the GWDG cloud
server. The server OS was set to Ubuntu 18.04.

## Server setup

### nf-core/eager

```bash
## Java
sudo apt install openjdk-11-jdk

## Nextflow
mkdir bin && cd !$
curl -s https://get.nextflow.io | bash

# Put nextflow in PATH, not necessary but :shrug:
echo 'PATH=$PATH:/home/cloud/bin/' > ~/.bash_profile
source ~/.bash_profile

## Run test
nextflow run hello

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



## Singularity Dependencies (also used for EAGER)
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

## Go
curl -O https://dl.google.com/go/go1.14.4.linux-amd64.tar.gz
tar xvf go1.14.4.linux-amd64.tar.gz
sudo chown -R root:root ./go
sudo mv go /usr/local
echo 'export GOPATH=$HOME/work
export PATH=$PATH:/usr/local/go/bin:$GOPATH/bin' >> ~/.bash_profile
 source ~/.bash_profile
rm go1.14.4.linux-amd64.tar.gz

# Singularity itself
export VERSION=3.5.2 && # adjust this as necessary \
    wget https://github.com/sylabs/singularity/releases/download/v${VERSION}/singularity-${VERSION}.tar.gz && \
    tar -xzf singularity-${VERSION}.tar.gz && \
    cd singularity

    ./mconfig && \
    make -C builddir && \
    sudo make -C builddir install

rm singularity-3.5.2.tar.gz
mv singularity/ bin/

## Now we will set up a singularity cache so all containers are in the same 
## place
mkdir -p .singularity/cache

echo 'export NXF_SINGULARITY_CACHEDIR=/home/cloud/.singularity/cache/nxf-cache' >> ~/.bash_profile

## get nf-core/eager

nextflow pull nf-core/eager -r dev
nextflow run nf-core/eager -r dev -profile test_tsv,singularity

```

### paleomix

The virtual env thing doesn't actually include all the software, as I
erroneously thought first time around. Lets try conda instead. Will use 2.7
as all of paleomix is in Python2.

```bash
cloud@eager-benchmark-setup:~$cd ~/bin
wget https://repo.anaconda.com/miniconda/Miniconda2-latest-Linux-x86_64.sh
chmod +x Miniconda2-latest-Linux-x86_64.sh
./Miniconda2-latest-Linux-x86_64.sh
## Follow instructions, install under ~/bin/miniconda2
conda config --set auto_activate_base false

echo 'export PATH=$PATH:/home/cloud/bin/miniconda2/bin' >> ~/.bash_profile
source ~/.bash_profile

conda config --add channels defaults
conda config --add channels bioconda
conda config --add channels conda-forge

# Make conda environment; note adding missing GATK and R requirement(s) not in docs: https://github.com/MikkelSchubert/paleomix/issues/28
conda create -n paleomix python=2.7 pip adapterremoval=2.3.1 samtools=1.9 picard=2.22.9 bowtie2=2.3.5.1 bwa=0.7.17 mapdamage2=2.0.9 gatk=3.8 r-base=3.5.1 r-rcpp=1.0.4.6 r-rcppgsl=0.3.7 r-gam=1.16.1 r-inline=0.3.15

conda activate paleomix

## Install paleomix
pip install --user paleomix

## Add ~/.local/bin to path
echo 'export PATH=$PATH:/home/cloud/.local/bin' >> ~/.bash_profile
source ~/.bash_profile

## Ok now we have some hardcoded dependcies to fix..
## Get the GATK JAR because not contained with GATK bioconda recipe because licensing
wget https://storage.googleapis.com/gatk-software/package-archive/gatk/GenomeAnalysisTK-3.8-1-0-gf15c1c3ef.tar.bz2
gatk3-register GenomeAnalysisTK-3.8-1-0-gf15c1c3ef.tar.bz2
mkdir -p /home/cloud/install/jar_root/
ln -s /home/cloud/bin/miniconda2/envs/paleomix/opt/gatk-3.8/GenomeAnalysisTK.jar /home/cloud/install/jar_root/
ln -s /home/cloud/bin/miniconda2/envs/paleomix/share/picard-2.22.9-0/picard.jar /home/cloud/install/jar_root/



## Run test
cd ~
paleomix bam_pipeline example .
cd ~/bam_pipeline
paleomix bam_pipeline run 000_makefile.yaml

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