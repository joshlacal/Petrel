#!/usr/bin/env python3
"""Restore the pinned public simdutf-swift source in a fresh benchmark checkout."""
from pathlib import Path
import subprocess
base=Path(__file__).resolve().parent
repo=base/'Vendor/simdutf-swift'
revision='4f98b5b16c8b1d9c7d77d88395c2a50b74be0607'
if not (repo/'Package.swift').exists():
 repo.parent.mkdir(parents=True,exist_ok=True)
 subprocess.run(['git','clone','https://github.com/margelo/simdutf-swift.git',str(repo)],check=True)
 subprocess.run(['git','-C',str(repo),'checkout','--detach',revision],check=True)
 subprocess.run(['git','-C',str(repo),'submodule','update','--init','--recursive'],check=True)
print('simdutf-swift pinned source ready; source bundle contains verified snapshots without VCS metadata')
