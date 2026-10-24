// Expected failure: RepoOp.cid is now optional, unlike the old nonoptional use.
import Petrel

func oldNonoptionalCIDUse(_ op: Petrel.ComAtprotoSyncSubscribeRepos.RepoOp) -> Petrel.CID {
    op.cid
}
