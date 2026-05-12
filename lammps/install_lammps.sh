#!/usr/bin/env bash
set -euo pipefail

# ─── Config ──────────────────────────────────────────────────────────────────
ENV_NAME="LAMMPS"
PYTHON_VERSION="3.11"
LAMMPS_BRANCH="stable"
NPROC=$(nproc)

# ─── Usage ───────────────────────────────────────────────────────────────────
MODE=""
INSTALL_DIR=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --hpc)         MODE="hpc"   ;;
        --local)       MODE="local" ;;
        --install-dir) INSTALL_DIR="$2"; shift ;;
        *) echo "Usage: $0 --hpc | --local [--install-dir PATH]" >&2; exit 1 ;;
    esac
    shift
done
[[ -z "$MODE" ]] && { echo "Error: specify --hpc or --local" >&2; exit 1; }

# ─── HPC: load system modules ────────────────────────────────────────────────
if [[ "$MODE" == "hpc" ]]; then
    module load GCC/12.2.0
    module load OpenMPI/4.1.4-GCC-12.2.0
    module load FFTW/3.3.10-GCC-12.2.0
    module load OpenBLAS/0.3.21-GCC-12.2.0
    module load CUDA/12.4.0
fi

# ─── Compilers ───────────────────────────────────────────────────────────────
if [[ "$MODE" == "hpc" ]]; then
    export CC=$(which gcc)
    export CXX=$(which g++)
    MPI_CXX=$(which mpicxx)
else
    export CC=/usr/bin/gcc
    export CXX=/usr/bin/g++
    MPI_CXX=/usr/bin/mpicxx
fi
export OMPI_CC="${CC}"
export OMPI_CXX="${CXX}"

if [[ "$MODE" == "hpc" ]]; then
    LAMMPS_SRC="${INSTALL_DIR:-${HOME}/lammps}"
    INSTALL_PREFIX="${HOME}/.local"
else
    LAMMPS_SRC="${INSTALL_DIR:-$(pwd)/lammps}"
    INSTALL_PREFIX=""
fi

# ─── Conda env ───────────────────────────────────────────────────────────────
# Inject conda shell functions so `conda activate` works in this subshell.
# shellcheck disable=SC2046
eval "$(conda shell.bash hook)"

if ! conda env list | grep -q "^${ENV_NAME} "; then
    conda create -n "${ENV_NAME}" python="${PYTHON_VERSION}" -y
fi
conda activate "${ENV_NAME}"

# ─── Clone LAMMPS ────────────────────────────────────────────────────────────
if [[ ! -d "${LAMMPS_SRC}/.git" ]]; then
    git clone -b "${LAMMPS_BRANCH}" https://github.com/lammps/lammps.git "${LAMMPS_SRC}"
fi
cd "${LAMMPS_SRC}" && mkdir -p build && cd build

# ─── CMake ───────────────────────────────────────────────────────────────────
cmake ../cmake \
  -C ../cmake/presets/most.cmake \
  -D BUILD_MPI=ON \
  -D BUILD_SHARED_LIBS=ON \
  -D PKG_REPLICA=ON \
  -D PKG_RIGID=ON \
  -D PKG_MANYBODY=ON \
  -D BUILD_OMP=ON \
  -D PKG_PYTHON=ON \
  -D PYTHON_EXECUTABLE="/mnt/parscratch/users/mtp24ele/anaconda/.envs/atom_sims/bin/python" \
  -D CMAKE_C_COMPILER="/opt/apps/testapps/el7/software/staging/GCCcore/12.2.0/bin/gcc" \
  -D CMAKE_CXX_COMPILER="/opt/apps/testapps/el7/software/staging/OpenMPI/4.1.4-GCC-12.2.0/bin/mpicxx" \
  ../cmake

# ─── Build & install ─────────────────────────────────────────────────────────
make -j"${NPROC}"
make install
make install-python

# ─── Python packages ─────────────────────────────────────────────────────────
conda install -y --strict-channel-priority \
    -c https://conda.ovito.org \
    -c conda-forge \
    ovito

conda install -y -c conda-forge \
    numpy pandas matplotlib scipy \
    ase matscipy atomman seaborn

pip install mpi4py --no-binary mpi4py

# ─── HPC: write modulefile ───────────────────────────────────────────────────
if [[ "$MODE" == "hpc" ]]; then
    CONDA_ROOT="$(conda info --base)"
    MODULE_DIR="${HOME}/modulefiles"
    mkdir -p "${MODULE_DIR}"

    cat > "${MODULE_DIR}/LAMMPS.lua" << EOF
-- ${MODULE_DIR}/LAMMPS.lua
help([[
  LAMMPS simulation environment.
  Includes: CUDA 12.4, OpenMPI 4.1.4, FFTW 3.3.10, OpenBLAS 0.3.21, OVITO, and Python 3.11.
]])
whatis("Description: LAMMPS/Python simulation environment")

-- ─── System modules ──────────────────────────────────────────────────────────
load("GCC/12.2.0")
load("OpenMPI/4.1.4-GCC-12.2.0")
load("FFTW/3.3.10-GCC-12.2.0")
load("OpenBLAS/0.3.21-GCC-12.2.0")
load("CUDA/12.4.0")
load("Anaconda3/2022.05")

-- ─── Paths ───────────────────────────────────────────────────────────────────
local HOME        = os.getenv("HOME")
local CONDA_ROOT  = "${CONDA_ROOT}"
local ENV_NAME    = "${ENV_NAME}"
local LMP_ROOT    = "${INSTALL_PREFIX}"
local LMP_BUILD   = pathJoin("${LAMMPS_SRC}", "build")
local LMP_PY      = pathJoin("${LAMMPS_SRC}", "python")

-- ─── Environment ─────────────────────────────────────────────────────────────
prepend_path("PATH",            pathJoin(CONDA_ROOT, ".envs", ENV_NAME, "bin"))
prepend_path("PATH",            pathJoin(LMP_ROOT, "bin"))
prepend_path("LD_LIBRARY_PATH", LMP_BUILD)
prepend_path("PYTHONPATH",      LMP_PY)

setenv("LAMMPS_ACTIVE", "1")
EOF

    echo "Modulefile written to: ${MODULE_DIR}/LAMMPS.lua"
    echo "Register with: module use ${MODULE_DIR}"
fi
