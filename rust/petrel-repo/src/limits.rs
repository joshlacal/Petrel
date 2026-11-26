use crate::error::{LimitError, LimitKind};

/// Bounded operational limits enforced during CAR import, MST validation,
/// record validation, and commit construction.
///
/// Mirrors `PublicRepositoryLimits` in Swift.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct RepositoryLimits {
    pub max_block_count: usize,
    pub max_record_count: usize,
    pub max_import_car_bytes: usize,
    pub max_relevant_block_bytes: usize,
    pub max_writes_per_commit: usize,
    pub max_single_block_bytes: usize,
    pub max_mst_node_count: usize,
    pub max_mst_depth: usize,
    pub max_car_roots: usize,
}

impl RepositoryLimits {
    /// Absolute safety ceilings across all configurations.
    pub const MAXIMUM_PERMITTED_BLOCK_COUNT: usize = 250_000;
    pub const MAXIMUM_PERMITTED_RECORD_COUNT: usize = 250_000;
    pub const MAXIMUM_PERMITTED_IMPORT_CAR_BYTES: usize = 512 * 1024 * 1024;
    pub const MAXIMUM_PERMITTED_RELEVANT_BLOCK_BYTES: usize = 16 * 1024 * 1024;
    pub const MAXIMUM_PERMITTED_WRITES_PER_COMMIT: usize = 2_000;
    pub const MAXIMUM_PERMITTED_SINGLE_BLOCK_BYTES: usize = 2 * 1024 * 1024;
    pub const MAXIMUM_PERMITTED_MST_NODE_COUNT: usize = 250_000;
    pub const MAXIMUM_PERMITTED_MST_DEPTH: usize = 128;

    /// Threshold above which CAR parsing should prefer streaming into a disk store.
    pub const REQUIRED_STREAMING_CAR_BYTES: usize = 256 * 1024 * 1024;

    /// Pinned ATProto commit budgets.
    pub const PINNED_MAXIMUM_WRITES: usize = 200;
    pub const PINNED_MAXIMUM_RELEVANT_BLOCK_BYTES: usize = 2_000_000;

    /// Standard limits suitable for typical client repositories.
    pub const fn standard() -> Self {
        Self {
            max_block_count: 50_000,
            max_record_count: 50_000,
            max_import_car_bytes: 64 * 1024 * 1024,
            max_relevant_block_bytes: Self::PINNED_MAXIMUM_RELEVANT_BLOCK_BYTES,
            max_writes_per_commit: Self::PINNED_MAXIMUM_WRITES,
            max_single_block_bytes: 1_048_576,
            max_mst_node_count: 50_000,
            max_mst_depth: 64,
            max_car_roots: 1,
        }
    }

    /// Network-scale limits supporting large repositories up to the hard ceilings.
    pub const fn network_scale() -> Self {
        Self {
            max_block_count: Self::MAXIMUM_PERMITTED_BLOCK_COUNT,
            max_record_count: Self::MAXIMUM_PERMITTED_RECORD_COUNT,
            max_import_car_bytes: Self::MAXIMUM_PERMITTED_IMPORT_CAR_BYTES,
            max_relevant_block_bytes: Self::MAXIMUM_PERMITTED_RELEVANT_BLOCK_BYTES,
            max_writes_per_commit: Self::MAXIMUM_PERMITTED_WRITES_PER_COMMIT,
            max_single_block_bytes: Self::MAXIMUM_PERMITTED_SINGLE_BLOCK_BYTES,
            max_mst_node_count: Self::MAXIMUM_PERMITTED_MST_NODE_COUNT,
            max_mst_depth: Self::MAXIMUM_PERMITTED_MST_DEPTH,
            max_car_roots: 1,
        }
    }

    /// Validates that every configured limit is positive and within hard ceilings.
    pub fn validate(&self) -> Result<(), LimitError> {
        check_range(
            "max_block_count",
            self.max_block_count,
            Self::MAXIMUM_PERMITTED_BLOCK_COUNT,
        )?;
        check_range(
            "max_record_count",
            self.max_record_count,
            Self::MAXIMUM_PERMITTED_RECORD_COUNT,
        )?;
        check_range(
            "max_import_car_bytes",
            self.max_import_car_bytes,
            Self::MAXIMUM_PERMITTED_IMPORT_CAR_BYTES,
        )?;
        check_range(
            "max_relevant_block_bytes",
            self.max_relevant_block_bytes,
            Self::MAXIMUM_PERMITTED_RELEVANT_BLOCK_BYTES,
        )?;
        check_range(
            "max_writes_per_commit",
            self.max_writes_per_commit,
            Self::MAXIMUM_PERMITTED_WRITES_PER_COMMIT,
        )?;
        check_range(
            "max_single_block_bytes",
            self.max_single_block_bytes,
            Self::MAXIMUM_PERMITTED_SINGLE_BLOCK_BYTES,
        )?;
        check_range(
            "max_mst_node_count",
            self.max_mst_node_count,
            Self::MAXIMUM_PERMITTED_MST_NODE_COUNT,
        )?;
        check_range(
            "max_mst_depth",
            self.max_mst_depth,
            Self::MAXIMUM_PERMITTED_MST_DEPTH,
        )?;
        if self.max_car_roots == 0 {
            return Err(LimitError::InvalidConfiguration(
                "max_car_roots must be at least 1".into(),
            ));
        }
        if self.max_record_count > self.max_block_count {
            return Err(LimitError::InvalidConfiguration(
                "max_record_count cannot exceed max_block_count".into(),
            ));
        }
        if self.max_mst_node_count > self.max_block_count {
            return Err(LimitError::InvalidConfiguration(
                "max_mst_node_count cannot exceed max_block_count".into(),
            ));
        }
        Ok(())
    }

    /// Checks an observed value against a limit of `kind`.
    pub fn check(&self, kind: LimitKind, observed: usize) -> Result<(), LimitError> {
        let limit = self.limit_for(kind);
        if observed > limit {
            return Err(LimitError::Exceeded {
                kind,
                observed,
                limit,
            });
        }
        Ok(())
    }

    /// Returns the configured ceiling for `kind`.
    pub const fn limit_for(&self, kind: LimitKind) -> usize {
        match kind {
            LimitKind::BlockCount => self.max_block_count,
            LimitKind::RecordCount => self.max_record_count,
            LimitKind::ImportCarBytes => self.max_import_car_bytes,
            LimitKind::RelevantBlockBytes => self.max_relevant_block_bytes,
            LimitKind::WritesPerCommit => self.max_writes_per_commit,
            LimitKind::SingleBlockBytes => self.max_single_block_bytes,
            LimitKind::MstNodeCount => self.max_mst_node_count,
            LimitKind::MstDepth => self.max_mst_depth,
            LimitKind::CarRootCount => self.max_car_roots,
        }
    }
}

impl Default for RepositoryLimits {
    fn default() -> Self {
        Self::standard()
    }
}

fn check_range(name: &str, value: usize, max: usize) -> Result<(), LimitError> {
    if value == 0 {
        return Err(LimitError::InvalidConfiguration(format!(
            "{name} must be positive"
        )));
    }
    if value > max {
        return Err(LimitError::InvalidConfiguration(format!(
            "{name} ({value}) exceeds hard ceiling ({max})"
        )));
    }
    Ok(())
}
