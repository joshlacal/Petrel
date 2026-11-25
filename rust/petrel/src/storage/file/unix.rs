use std::fs::File;
use std::io::{self, ErrorKind};
use std::path::{Component, Path};

use rustix::fd::OwnedFd;
use rustix::fs::{AtFlags, Dir, FlockOperation, Mode, OFlags};
use rustix::process::getuid;

use super::optional;

const DIR_FLAGS: OFlags = OFlags::RDONLY
    .union(OFlags::DIRECTORY)
    .union(OFlags::NOFOLLOW)
    .union(OFlags::CLOEXEC);
const FILE_FLAGS: OFlags = OFlags::NOFOLLOW
    .union(OFlags::NONBLOCK)
    .union(OFlags::CLOEXEC);
const DIR_MODE: Mode = Mode::RUSR.union(Mode::WUSR).union(Mode::XUSR);
const FILE_MODE: Mode = Mode::RUSR.union(Mode::WUSR);

pub(super) struct Directory(OwnedFd);

impl Directory {
    pub(super) fn open(path: &Path) -> io::Result<Self> {
        if path.as_os_str().is_empty() {
            return Err(ErrorKind::InvalidInput.into());
        }
        let path = std::env::current_dir()?.join(path);
        let mut directory = rustix::fs::open("/", DIR_FLAGS, Mode::empty())?;
        for component in path.components() {
            match component {
                Component::RootDir | Component::CurDir => {}
                Component::Normal(name) => {
                    directory = match rustix::fs::openat(&directory, name, DIR_FLAGS, Mode::empty())
                    {
                        Err(rustix::io::Errno::NOENT) => {
                            match rustix::fs::mkdirat(&directory, name, DIR_MODE) {
                                Ok(()) => rustix::fs::fsync(&directory)?,
                                Err(rustix::io::Errno::EXIST) => {}
                                Err(error) => return Err(error.into()),
                            }
                            rustix::fs::openat(&directory, name, DIR_FLAGS, Mode::empty())?
                        }
                        result => result?,
                    };
                }
                _ => return Err(ErrorKind::InvalidInput.into()),
            }
        }
        let directory = Self(directory);
        directory.check_directory()?;
        Ok(directory)
    }

    fn check_directory(&self) -> io::Result<()> {
        let metadata = rustix::fs::fstat(&self.0)?;
        if metadata.st_nlink == 0 {
            return Err(ErrorKind::NotFound.into());
        }
        check_owner(&metadata)
    }

    pub(super) fn lock(&self) -> io::Result<OwnedFd> {
        self.check_directory()?;
        // Open a separate file description. Duplicating the existing descriptor would
        // share its advisory lock and fail to serialize threads using one store.
        let lock = rustix::fs::openat(&self.0, ".", DIR_FLAGS, Mode::empty())?;
        rustix::fs::flock(&lock, FlockOperation::LockExclusive)?;
        Ok(lock)
    }

    pub(super) fn names(&self) -> io::Result<Vec<String>> {
        let mut names = Vec::new();
        for entry in Dir::read_from(&self.0)? {
            let entry = entry?;
            if let Ok(name) = entry.file_name().to_str() {
                names.push(name.to_owned());
            }
        }
        Ok(names)
    }

    pub(super) fn read_file(&self, name: &str) -> io::Result<Option<File>> {
        let open = rustix::fs::openat(&self.0, name, OFlags::RDONLY | FILE_FLAGS, Mode::empty());
        let Some(file) = optional(open.map_err(io::Error::from))? else {
            return Ok(None);
        };
        let metadata = rustix::fs::fstat(&file)?;
        if rustix::fs::FileType::from_raw_mode(metadata.st_mode)
            != rustix::fs::FileType::RegularFile
        {
            return Err(ErrorKind::PermissionDenied.into());
        }
        check_owner(&metadata)?;
        Ok(Some(File::from(file)))
    }

    pub(super) fn create_file(&self, name: &str) -> io::Result<File> {
        let file = rustix::fs::openat(
            &self.0,
            name,
            OFlags::WRONLY | OFlags::CREATE | OFlags::EXCL | FILE_FLAGS,
            FILE_MODE,
        )?;
        Ok(File::from(file))
    }

    pub(super) fn rename(&self, source: &str, target: &str) -> io::Result<()> {
        Ok(rustix::fs::renameat(&self.0, source, &self.0, target)?)
    }

    pub(super) fn link(&self, source: &str, target: &str) -> io::Result<()> {
        Ok(rustix::fs::linkat(
            &self.0,
            source,
            &self.0,
            target,
            AtFlags::empty(),
        )?)
    }

    pub(super) fn remove(&self, name: &str) -> io::Result<bool> {
        let result = rustix::fs::unlinkat(&self.0, name, AtFlags::empty());
        Ok(optional(result.map_err(io::Error::from))?.is_some())
    }

    pub(super) fn sync(&self) -> io::Result<()> {
        Ok(rustix::fs::fsync(&self.0)?)
    }
}

fn check_owner(metadata: &rustix::fs::Stat) -> io::Result<()> {
    if metadata.st_uid != getuid().as_raw() || metadata.st_mode & 0o077 != 0 {
        return Err(ErrorKind::PermissionDenied.into());
    }
    Ok(())
}
