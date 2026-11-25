use crate::error::{LimitError, LimitKind};
use crate::limits::RepositoryLimits;

/// Incremental resource-usage counter checked against [`RepositoryLimits`]
/// during streaming import, MST validation, and commit construction
/// (`RepositoryFootprint`).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub struct RepositoryFootprint {
    pub block_count: usize,
    pub record_count: usize,
    pub mst_node_count: usize,
    pub import_car_bytes: usize,
    pub relevant_block_bytes: usize,
    pub max_mst_depth: usize,
}

impl RepositoryFootprint {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn add_block(
        &mut self,
        block_bytes: usize,
        limits: &RepositoryLimits,
    ) -> Result<(), LimitError> {
        limits.check(LimitKind::SingleBlockBytes, block_bytes)?;
        self.block_count += 1;
        limits.check(LimitKind::BlockCount, self.block_count)?;
        self.relevant_block_bytes = self.relevant_block_bytes.saturating_add(block_bytes);
        Ok(())
    }

    pub fn add_record(
        &mut self,
        record_bytes: usize,
        limits: &RepositoryLimits,
    ) -> Result<(), LimitError> {
        limits.check(LimitKind::SingleBlockBytes, record_bytes)?;
        self.record_count += 1;
        limits.check(LimitKind::RecordCount, self.record_count)?;
        Ok(())
    }

    pub fn add_mst_node(
        &mut self,
        depth: usize,
        limits: &RepositoryLimits,
    ) -> Result<(), LimitError> {
        self.mst_node_count += 1;
        limits.check(LimitKind::MstNodeCount, self.mst_node_count)?;
        self.max_mst_depth = self.max_mst_depth.max(depth);
        limits.check(LimitKind::MstDepth, self.max_mst_depth)?;
        Ok(())
    }

    pub fn check_all(&self, limits: &RepositoryLimits) -> Result<(), LimitError> {
        limits.validate()?;
        limits.check(LimitKind::BlockCount, self.block_count)?;
        limits.check(LimitKind::RecordCount, self.record_count)?;
        limits.check(LimitKind::MstNodeCount, self.mst_node_count)?;
        limits.check(LimitKind::ImportCarBytes, self.import_car_bytes)?;
        limits.check(LimitKind::RelevantBlockBytes, self.relevant_block_bytes)?;
        limits.check(LimitKind::MstDepth, self.max_mst_depth)?;
        Ok(())
    }
}
