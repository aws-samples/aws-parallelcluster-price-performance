#!/bin/bash
#$ -cwd
#$ -j y
#$ -pe mpi 144
#$ -S /bin/bash
module load mpi/openmpi-x86_64
mpirun -np 144 hostname