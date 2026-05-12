# softwarehub

A collection of installation scripts for computational materials science software. Each script supports both a local workstation and the [Stanage HPC cluster](https://docs.hpc.shef.ac.uk/en/latest/stanage/index.html) via a single `--local` / `--hpc` flag, producing equivalent environments on both.

---

## Prerequisites

### HPC: first-time setup

1. **HPC training** — complete the University of Sheffield HPC training before using Stanage.

2. **Conda** — follow the Sheffield HPC Python guide to get conda set up in your HPC environment:
   [https://docs.hpc.shef.ac.uk/en/latest/stanage/software/apps/python.html](https://docs.hpc.shef.ac.uk/en/latest/stanage/software/apps/python.html)

3. **Filestore** — set up your `fastdata` area for large files (LAMMPS source, simulation output, etc.):
   [https://docs.hpc.shef.ac.uk/en/latest/hpc/filestore.html](https://docs.hpc.shef.ac.uk/en/latest/hpc/filestore.html)
   (See the *Fast data areas* section.)

### Local: dependencies

- `gcc`, `g++`, `mpicxx` available at `/usr/bin/`
- `conda` (Miniconda or Anaconda)
- `git`, `cmake`

---

## Getting the scripts

Clone this repo locally and on the HPC:

```bash
git clone https://github.com/Eledmunds15/softwarehub.git
```

To update on either machine:

```bash
git pull
```

---

## Available installers

### LAMMPS

Installs [LAMMPS](https://www.lammps.org/) (molecular dynamics simulator) from source into a dedicated conda environment.

```bash
cd lammps
bash install_lammps.sh --local [--install-dir PATH]   # workstation
bash install_lammps.sh --hpc   [--install-dir PATH]   # Stanage
```

See [lammps/README.md](lammps/README.md) for full details.

---

## Planned installers

- **OpenDis** — dislocation dynamics simulator
- **MOOSE** — multiphysics finite element framework
- **DAMASK** — crystal plasticity simulation package

---

## Repository layout

```
softwarehub/
└── lammps/
    ├── install_lammps.sh   # installer (--local / --hpc)
    └── README.md           # LAMMPS-specific docs
```
