# LAMMPS Installation Script

`install_lammps.sh` installs [LAMMPS](https://www.lammps.org/) from source into a conda environment. It supports both a local workstation and an HPC cluster via a single flag, producing equivalent environments on both.

---

## Usage

```bash
bash install_lammps.sh --local [--install-dir PATH]
bash install_lammps.sh --hpc   [--install-dir PATH]
```

### Flags

| Flag | Required | Description |
|------|----------|-------------|
| `--local` | Yes (or `--hpc`) | Install for a local workstation using system compilers |
| `--hpc` | Yes (or `--local`) | Install for an HPC cluster using environment modules |
| `--install-dir PATH` | No | Override the default install location (see defaults below) |

### Default install locations

| Mode | Default |
|------|---------|
| `--local` | `./lammps` (relative to where the script is run) |
| `--hpc` | `~/.local/lammps/src` |

---

## Local prerequisites

Install the required system packages on Ubuntu/Debian before running the script:

```bash
sudo apt update && sudo apt install -y \
    build-essential \
    gcc g++ \
    cmake \
    openmpi-bin libopenmpi-dev \
    git
```

The script uses the system compilers at `/usr/bin/gcc`, `/usr/bin/g++`, and `/usr/bin/mpicxx`. These are provided by `build-essential`, `g++`, and `libopenmpi-dev` respectively.

---

## What the script does

1. **Loads system modules** (`--hpc` only)
   Loads GCC 12.2.0, OpenMPI 4.1.4, FFTW 3.3.10, OpenBLAS 0.3.21, and CUDA 12.4 via `module load`.

2. **Sets compilers**
   - `--hpc`: resolves `gcc`, `g++`, `mpicxx` from the loaded modules via `which`
   - `--local`: hardcodes `/usr/bin/gcc`, `/usr/bin/g++`, `/usr/bin/mpicxx`

3. **Creates a conda environment** named `LAMMPS` with Python 3.12.

4. **Clones LAMMPS** (`stable` branch) from GitHub into the install directory.

5. **Configures with CMake** using the `most.cmake` preset plus:
   - MPI, OpenMP, shared libs
   - Packages: `PYTHON`, `REPLICA`, `RIGID`, `MANYBODY`
   - `--hpc` also sets `CMAKE_INSTALL_PREFIX` to the install directory

6. **Builds and installs** LAMMPS and its Python bindings (`make install-python`).

7. **Installs Python packages** into the conda environment:
   - OVITO (from the OVITO conda channel)
   - numpy, pandas, matplotlib, scipy, ASE, matscipy, atomman, seaborn
   - mpi4py (built from source against the active MPI)

8. **Writes an Lmod modulefile** (`--hpc` only) to `~/modulefiles/LAMMPS.lua`, which loads all required system modules and sets `PATH`, `LD_LIBRARY_PATH`, and `PYTHONPATH` appropriately.

---

## Parameters to change

All configurable values are at the top of the script:

| Variable | Default | Description |
|----------|---------|-------------|
| `ENV_NAME` | `LAMMPS` | Name of the conda environment |
| `PYTHON_VERSION` | `3.11` | Python version for the conda environment (3.11 max — OVITO's conda channel does not yet support 3.12) |
| `LAMMPS_BRANCH` | `stable` | LAMMPS git branch to clone |
| `NPROC` | `$(nproc)` | Number of parallel build jobs |

HPC module versions (edit the `module load` lines directly):

| Module | Version |
|--------|---------|
| GCC | 12.2.0 |
| OpenMPI | 4.1.4-GCC-12.2.0 |
| FFTW | 3.3.10-GCC-12.2.0 |
| OpenBLAS | 0.3.21-GCC-12.2.0 |
| CUDA | 12.4.0 |

---

## Examples

```bash
# Workstation — clone into ./lammps in the current directory
bash install_lammps.sh --local

# Workstation — clone into a specific directory
bash install_lammps.sh --local --install-dir /opt/lammps

# HPC cluster — install into ~/.local/lammps/src (default)
bash install_lammps.sh --hpc

# HPC cluster — install into a shared project directory
bash install_lammps.sh --hpc --install-dir /shared/projects/lammps
```

After an `--hpc` install, register and load the modulefile:

```bash
module use ~/modulefiles
module load LAMMPS
```

Verify the installation in either mode:

```bash
lmp -help
python -c "import lammps; print('OK')"
```

## How to run simulations

### Local

```bash
conda activate LAMMPS
lmp -in in.script
```

or

```bash
conda activate LAMMPS
python in.py
```

### HPC (SLURM batch script)

```bash
#!/bin/bash
#SBATCH --job-name=my_lammps_job
#SBATCH --ntasks=32
#SBATCH --mem=16G
#SBATCH --time=01:00:00
#SBATCH --output=slurm-%j.out

module use $HOME/modulefiles
module load LAMMPS
eval "$(conda shell.bash hook)"
conda activate LAMMPS

export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK

srun --export=ALL lmp -in in.script
```

or

```bash
#!/bin/bash
#SBATCH --job-name=my_lammps_job
#SBATCH --ntasks=32
#SBATCH --mem=16G
#SBATCH --time=01:00:00
#SBATCH --output=slurm-%j.out

module use $HOME/modulefiles
module load LAMMPS
eval "$(conda shell.bash hook)"
conda activate LAMMPS

export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK

srun --export=ALL python in.py
```


Submit with:

```bash
sbatch job.sh
```
