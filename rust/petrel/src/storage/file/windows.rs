use std::fs::{self, File, OpenOptions};
use std::io::{self, ErrorKind};
use std::os::windows::fs::{MetadataExt as _, OpenOptionsExt as _};
use std::path::{Component, Path, PathBuf};

use super::optional;

// These Windows flags apply to file opens and metadata respectively.
const FILE_FLAG_OPEN_REPARSE_POINT: u32 = 0x0020_0000;
const FILE_ATTRIBUTE_REPARSE_POINT: u32 = 0x0400;

pub(super) struct Directory(PathBuf);

impl Directory {
    pub(super) fn open(path: &Path) -> io::Result<Self> {
        if path.as_os_str().is_empty() {
            return Err(ErrorKind::InvalidInput.into());
        }
        let absolute = std::env::current_dir()?.join(path);
        let mut directory = PathBuf::new();
        for component in absolute.components() {
            directory.push(component.as_os_str());
            match component {
                Component::ParentDir => return Err(ErrorKind::InvalidInput.into()),
                Component::Normal(_) => {
                    if optional(fs::symlink_metadata(&directory))?.is_none() {
                        match fs::create_dir(&directory) {
                            Ok(()) => {}
                            Err(error) if error.kind() == ErrorKind::AlreadyExists => {}
                            Err(error) => return Err(error),
                        }
                    }
                    check_directory(&directory)?;
                }
                _ => {}
            }
        }
        check_directory(&directory)?;
        Ok(Self(directory))
    }

    pub(super) fn lock(&self) -> io::Result<File> {
        check_directory(&self.0)?;
        let file = OpenOptions::new()
            .read(true)
            .write(true)
            .create(true)
            .truncate(false)
            .custom_flags(FILE_FLAG_OPEN_REPARSE_POINT)
            .open(self.0.join(".petrel-lock"))?;
        check_file(&file)?;
        fs4::FileExt::lock(&file)?;
        Ok(file)
    }

    pub(super) fn names(&self) -> io::Result<Vec<String>> {
        let mut names = Vec::new();
        for entry in fs::read_dir(&self.0)? {
            if let Ok(name) = entry?.file_name().into_string() {
                names.push(name);
            }
        }
        Ok(names)
    }

    pub(super) fn read_file(&self, name: &str) -> io::Result<Option<File>> {
        let open = OpenOptions::new()
            .read(true)
            .custom_flags(FILE_FLAG_OPEN_REPARSE_POINT)
            .open(self.0.join(name));
        let Some(file) = optional(open)? else {
            return Ok(None);
        };
        check_file(&file)?;
        Ok(Some(file))
    }

    pub(super) fn create_file(&self, name: &str) -> io::Result<File> {
        OpenOptions::new()
            .write(true)
            .create_new(true)
            .custom_flags(FILE_FLAG_OPEN_REPARSE_POINT)
            .open(self.0.join(name))
    }

    pub(super) fn rename(&self, source: &str, target: &str) -> io::Result<()> {
        fs::rename(self.0.join(source), self.0.join(target))
    }

    pub(super) fn link(&self, source: &str, target: &str) -> io::Result<()> {
        fs::hard_link(self.0.join(source), self.0.join(target))
    }

    pub(super) fn remove(&self, name: &str) -> io::Result<bool> {
        Ok(optional(fs::remove_file(self.0.join(name)))?.is_some())
    }

    // File data is flushed before replacement. std has no Windows directory fsync.
    #[allow(clippy::unnecessary_wraps, clippy::unused_self)]
    pub(super) fn sync(&self) -> io::Result<()> {
        Ok(())
    }
}

fn check_directory(directory: &Path) -> io::Result<()> {
    let metadata = fs::symlink_metadata(directory)?;
    if !metadata.is_dir() || metadata.file_attributes() & FILE_ATTRIBUTE_REPARSE_POINT != 0 {
        return Err(ErrorKind::PermissionDenied.into());
    }
    Ok(())
}

fn check_file(file: &File) -> io::Result<()> {
    let metadata = file.metadata()?;
    if !metadata.is_file() || metadata.file_attributes() & FILE_ATTRIBUTE_REPARSE_POINT != 0 {
        return Err(ErrorKind::PermissionDenied.into());
    }
    Ok(())
}
