// Emits `../Fixtures/upstream-oauth-scopes.json` by running the reference
// implementation's own `@atproto/oauth-scopes` (bluesky-social/atproto), unbuilt,
// at the commit pinned below. No expected value in the corpus is hand-written:
// every one is whatever the TypeScript returned.
//
// Do not run this file directly. `regenerate.sh` copies the three upstream
// packages it needs, bundles this file against them and writes the fixture.

import {
  IncludeScope,
  ScopePermissions,
  ScopePermissionsTransition,
  isAtprotoDidRefAbsolute,
  isAtprotoOauthScope,
  isNsid,
  normalizeAtprotoOauthScope,
  normalizeAtprotoOauthScopeValue,
} from '@atproto/oauth-scopes'
// Not re-exported from the package index.
import { isAccept, isMime } from '@atproto/oauth-scopes/src/lib/mime.ts'

const REFERENCE_COMMIT = '0e1042e65d5df27030849167773728b84d469182'

// Upstream throws rather than returning null on one class of input: a malformed
// percent escape in a positional is `decodeURIComponent`'s uncaught URIError
// (lib/syntax-string.ts). Every call is guarded so such a row is recorded
// instead of aborting the run.
const call = (fn) => {
  try {
    return { value: fn(), threw: null }
  } catch (err) {
    return { value: null, threw: String(err && err.message ? err.message : err) }
  }
}

// --- 1. Per-value parse + canonical form ------------------------------------

const SCOPE_VALUES = [
  // The four parameterless values.
  'atproto',
  'transition:generic',
  'transition:email',
  'transition:chat.bsky',
  'transition:unknown',
  'atproto:foo',
  'atproto?x=1',

  // Every scope string in https://atproto.com/specs/permission, in document
  // order: per-resource examples, the positional/named equivalence and
  // conflict, "syntactically and semantically valid", "valid syntax but no
  // semantics", and "do not match the general syntax".
  'repo:app.example.profile',
  'repo:app.example.profile?action=create&action=update&action=delete',
  'repo?collection=app.example.profile&collection=app.example.post',
  'repo:*',
  'repo:*?action=delete',
  'rpc:app.example.moderation.createReport?aud=*',
  'rpc?lxm=*&aud=did:web:api.example.com%23svc_appview',
  'blob:*/*',
  'blob?accept=video/*&accept=text/html',
  'account:email',
  'account:repo?action=manage',
  'identity:handle',
  'account?action=manage&attr=repo',
  'repo:com.example.record?collection=com.example.other',
  'identity:*',
  'identity:*?',
  'include:app.example.authFull?aud=did:web:api.example.com%23svc_chat',
  'resource',
  'resource:positional?key=val',
  'resource:positional&thing?key=val',
  'service:did:web:com.example#type?key=val',
  'resource:',
  'resource:?',
  'resource:&',
  'resource?',
  'resource:positional?key=québec',
  'emoji:☺️',
  'include:com.example.authBasicFeatures?aud=did:web:api.example.com%23svc_appview',

  // repo
  'repo:app.bsky.feed.post',
  'repo:app.bsky.feed.post?action=create',
  'repo:app.bsky.feed.post?action=create&action=delete',
  'repo:app.bsky.feed.post?action=delete&action=create',
  'repo:app.bsky.feed.post?action=create&action=create',
  'repo?collection=app.bsky.feed.post&collection=app.bsky.feed.post',
  'repo?collection=app.bsky.feed.post&collection=app.bsky.feed.like&action=update',
  'repo?collection=*&collection=app.bsky.feed.post',
  'repo:app.bsky.*',
  'repo:com.example.foo?action=*',
  'repo:*?action=create&unknown=1',
  'repo:com.example.foo?action=',
  'repo',
  'repo?',
  'repo:',
  'repo:?action=create',
  'repo?action=create',

  // NSID edges, through the `collection` validator.
  'repo:com.example.1foo',
  'repo:com.example.foo1',
  'repo:com.example.foo-bar',
  'repo:com.example-.foo',
  'repo:com.-example.foo',
  'repo:com.9example.foo',
  'repo:9com.example.foo',
  'repo:com.example',
  'repo:a.b.c',
  'repo:com.example.Foo',
  'repo:COM.EXAMPLE.foo',
  'repo:com.example.foo.',
  'repo:com..foo',

  // rpc
  'rpc:app.bsky.feed.getFeed?aud=did:web:example.com#bsky_fg',
  'rpc:app.bsky.feed.getFeed?aud=did:web:example.com%23bsky_fg',
  'rpc:app.bsky.feed.getFeed?aud=did:plc:z72i7hdynmk6r22z27h6tvur%23bsky_fg',
  'rpc:app.bsky.feed.getFeed?aud=*',
  'rpc:*?aud=did:web:example.com%23bsky_fg',
  'rpc:*?aud=*',
  'rpc?lxm=*&aud=*',
  'rpc:*',
  'rpc:app.bsky.feed.getFeed',
  'rpc?lxm=app.bsky.feed.getFeed&lxm=*&aud=did:web:example.com%23bsky_fg',
  'rpc?lxm=com.example.b&lxm=com.example.a&aud=*',
  'rpc?lxm=com.example.a&lxm=com.example.a&aud=*',
  'rpc?aud=*&lxm=com.example.a',
  'rpc:app.bsky.feed.getFeed?aud=did:web:example.com',
  'rpc:app.bsky.feed.getFeed?aud=did:example:456%23service_id',
  'rpc:app.bsky.feed.getFeed?aud=did:web:example.com:path%23bsky_fg',
  'rpc:app.bsky.feed.getFeed?aud=did:web:localhost%3A8080%23svc',
  'rpc:app.bsky.feed.getFeed?aud=did:web:localhost%253A8080%23svc',
  'rpc:app.bsky.feed.getFeed?aud=did:web:ex%ample.com%23svc',
  'rpc:app.bsky.feed.getFeed?aud=',
  'rpc:app.bsky.feed.getFeed?aud=%',

  // The two serialisers and the characters they disagree on, through a real
  // parameter: the fragment of an `rpc` audience.
  'rpc:app.bsky.feed.getFeed?aud=did:web:example.com%23a~b',
  'rpc:app.bsky.feed.getFeed?aud=did:web:example.com%23a%7Eb',
  'rpc:app.bsky.feed.getFeed?aud=did:web:example.com%23a+b',
  'rpc:app.bsky.feed.getFeed?aud=did:web:example.com%23a%2Bb',
  'rpc:app.bsky.feed.getFeed?aud=did:web:example.com%23a%20b',
  'rpc:app.bsky.feed.getFeed?aud=did:web:example.com%23a,b',
  'rpc:app.bsky.feed.getFeed?aud=did:web:example.com%23a:b',
  'rpc:app.bsky.feed.getFeed?aud=did:web:example.com%23a/b',
  'rpc:app.bsky.feed.getFeed?aud=did:web:example.com%23a@b',
  'rpc:app.bsky.feed.getFeed?aud=did:web:example.com%23a%25b',
  'rpc:app.bsky.feed.getFeed?aud=did:web:example.com%23a%2541',
  'rpc:app.bsky.feed.getFeed?aud=did:web:example.com%23a%26b',
  'rpc:app.bsky.feed.getFeed?aud=did:web:example.com%23a%3Db',

  // blob
  'blob:image/png',
  'blob:image/*',
  'blob:IMAGE/PNG',
  'blob:image/svg+xml',
  'blob?accept=image/svg+xml',
  'blob?accept=image/svg%2Bxml',
  'blob?accept=image/svg%2Bxml&accept=image/png',
  'blob?accept=image/png&accept=image/jpeg',
  'blob?accept=image/*&accept=image/png&accept=text/plain',
  'blob?accept=*/*&accept=image/png',
  'blob?accept=image/png&accept=image/png',
  'blob:image%2Fpng',
  'blob:%2A/%2A',
  'blob',
  'blob:image',
  'blob:*',
  'blob:/image',
  'blob:image/',
  'blob:*/png',
  'blob:image/**',
  'blob:image/png/extra',
  'blob:im*ge/*',
  'blob:*a/*',
  'blob:im*ge/png',

  // account
  'account:email?action=manage',
  'account:email?action=read',
  'account:email?action=manage&action=read',
  'account:email?action=read&action=manage',
  'account:email?action=read&action=read',
  'account:status',
  'account:status?action=manage',
  'account:repo',
  'account?attr=email',
  'account:*',
  'account:EMAIL',
  'account:email?action=',
  'account:email?action=write',
  'account',
  'account:',

  // identity
  'identity:handle?',
  'identity?attr=handle',
  'identity?attr=*',
  'identity:*?action=manage',
  'identity:did',
  'identity',

  // include
  'include:com.example.permissionSet',
  'include:app.bulleted.authFull',
  'include?nsid=com.example.foo',
  'include?aud=did:web:example.com%23svc&nsid=com.example.foo',
  'include:com.example.foo?aud=*',
  'include:com.example.foo?aud=did:web:example.com',
  'include:com.example.foo?aud=did:web:example.com#svc',
  'include:com.example',
  'include:*',
  'include',

  // A parameter given both positionally and by name (lib/parser.ts).
  'account:email?attr=repo',
  'account:email?attr=email',
  'identity:handle?attr=*',
  'rpc:com.example.method1?aud=did:web:example.com&lxm=com.example.method2',
  'rpc:com.example.method1?aud=*&lxm=com.example.method2',
  'blob:image/png?accept=image/jpeg',
  'include:com.example.foo?nsid=com.example.foo',

  // A single-valued parameter given more than once. `repo` and `blob` cannot
  // appear here: every parameter they declare is multi-valued.
  'account?attr=email&attr=repo',
  'identity?attr=handle&attr=*',
  'include?nsid=com.example.foo&nsid=com.example.bar',
  'include:com.example.foo?aud=did:web:example.com%23a&aud=did:web:example.com%23b',
  'rpc:com.example.method?aud=did:web:example.com%23a&aud=did:web:example.com%23b',

  // Percent-escaped positional: decoded with `decodeURIComponent`, which
  // throws on a malformed escape.
  'repo:com%2Eexample%2Efoo',
  'identity:%2A',
  'account:100%',
  'repo:%zz',
  'repo:%E0%A4%A',

  // Empty query pairs and pairs without `=`.
  'rpc:com.example.method1?&aud=*',
  'rpc:com.example.method1?aud=*&',
  'rpc:com.example.method1?aud=*&&',
  'repo:com.example.foo?action',
  'identity:handle?=',

  // Unknown resources. `space` is not a resource at this commit.
  '',
  'notafamily:whatever',
  'openid',
  'identityfoo:bar',
  'repository:com.example.foo',
  'REPO:com.example.foo',
  'space:com.example.group',
  'space:com.example.group?action=read',
]

const values = SCOPE_VALUES.map((input) => {
  const normalized = call(() => normalizeAtprotoOauthScopeValue(input) ?? null)
  const canonical = normalized.value
  const recognized = call(() => isAtprotoOauthScope(input))
  const roundTrip =
    canonical === null
      ? { value: null }
      : call(() => normalizeAtprotoOauthScopeValue(canonical) === canonical)
  return {
    input,
    // `null` means upstream threw instead of answering.
    isAtprotoOauthScope: recognized.value,
    canonical,
    threw: normalized.threw ?? recognized.threw,
    roundTripStable: roundTrip.value,
  }
})

// --- 2. Whole scope-string normalisation ------------------------------------

const SCOPE_STRINGS = [
  'atproto',
  'atproto include:app.bulleted.authFull blob:image/*',
  'repo:app.bsky.feed.post atproto',
  'atproto atproto',
  'atproto notafamily:whatever',
  'atproto space:com.example.group',
  'transition:generic atproto transition:chat.bsky',
  'rpc?aud=*&lxm=com.example.a atproto repo?collection=*&action=create',
]

const strings = SCOPE_STRINGS.map((input) => ({
  input,
  normalized: normalizeAtprotoOauthScope(input),
}))

// --- 3. Match outcomes ------------------------------------------------------

const GRANTS = {
  atprotoOnly: 'atproto',
  bulleted: 'atproto include:app.bulleted.authFull blob:image/*',
  repoNarrow: 'atproto repo:app.bsky.feed.post?action=create',
  repoWide: 'atproto repo:*',
  repoTwo: 'atproto repo?collection=app.bsky.feed.post&collection=app.bsky.graph.follow&action=delete',
  blobImages: 'atproto blob:image/*',
  blobAny: 'atproto blob:*/*',
  identityHandle: 'atproto identity:handle',
  identityAny: 'atproto identity:*',
  accountEmail: 'atproto account:email',
  accountEmailManage: 'atproto account:email?action=manage',
  accountRepo: 'atproto account:repo',
  rpcNarrow: 'atproto rpc:app.bsky.feed.getFeed?aud=did:web:example.com%23bsky_fg',
  rpcAnyAudience: 'atproto rpc:app.bsky.feed.getFeed?aud=*',
  rpcAnyMethod: 'atproto rpc:*?aud=did:web:example.com%23bsky_fg',
  transitionGeneric: 'atproto transition:generic',
  transitionChat: 'atproto transition:chat.bsky',
  transitionEmail: 'atproto transition:email',
  transitionAll: 'atproto transition:generic transition:chat.bsky transition:email',
  transitionEmailAndAccountRepo: 'transition:email account:repo',
  unparseable: 'atproto repo:not-a-valid-nsid blob:* rpc:*?aud=* space:com.example.group',
  empty: '',
}

const REPO_CHECKS = [
  { action: 'create', collection: 'app.bsky.feed.post' },
  { action: 'update', collection: 'app.bsky.feed.post' },
  { action: 'delete', collection: 'app.bsky.feed.post' },
  { action: 'create', collection: 'app.bsky.graph.follow' },
  { action: 'delete', collection: 'app.bsky.graph.follow' },
  { action: 'create', collection: 'not-a-valid-nsid' },
]
const BLOB_CHECKS = [
  { mime: 'image/png' },
  { mime: 'image/svg+xml' },
  { mime: 'video/mp4' },
  { mime: 'image/' },
  { mime: 'image/*' },
  { mime: 'image' },
]
const RPC_CHECKS = [
  { aud: 'did:web:example.com#bsky_fg', lxm: 'app.bsky.feed.getFeed' },
  { aud: 'did:web:other.example#bsky_fg', lxm: 'app.bsky.feed.getFeed' },
  { aud: 'did:web:example.com', lxm: 'app.bsky.feed.getFeed' },
  { aud: 'did:web:example.com#bsky_fg', lxm: 'app.bsky.feed.getTimeline' },
  { aud: 'did:web:example.com#bsky_chat', lxm: 'chat.bsky.convo.getConvo' },
  { aud: 'did:web:example.com#bsky_chat', lxm: 'chat.bskyfoo.convo.getConvo' },
  { aud: 'did:web:example.com#bsky_fg', lxm: '*' },
]
const IDENTITY_CHECKS = [{ attr: 'handle' }, { attr: '*' }]
const ACCOUNT_CHECKS = [
  { attr: 'email', action: 'read' },
  { attr: 'email', action: 'manage' },
  { attr: 'repo', action: 'read' },
  { attr: 'repo', action: 'manage' },
  { attr: 'status', action: 'read' },
  { attr: 'status', action: 'manage' },
]

// The scope STRING goes to the constructor, which splits on SPACE
// (scope-permissions.ts). `ScopesSet extends Set<string>`, so handing the
// string to `new ScopesSet(...)` would iterate it character by character.
function outcomesFor(Permissions, scopeString) {
  const p = new Permissions(scopeString)
  const check = (fn, arg) => {
    try {
      return { arg, allowed: fn.call(p, arg), threw: null }
    } catch (err) {
      return { arg, allowed: null, threw: String(err && err.message ? err.message : err) }
    }
  }
  return {
    repo: REPO_CHECKS.map((a) => check(p.allowsRepo, a)),
    blob: BLOB_CHECKS.map((a) => check(p.allowsBlob, a)),
    rpc: RPC_CHECKS.map((a) => check(p.allowsRpc, a)),
    identity: IDENTITY_CHECKS.map((a) => check(p.allowsIdentity, a)),
    account: ACCOUNT_CHECKS.map((a) => check(p.allowsAccount, a)),
  }
}

const matches = Object.fromEntries(
  Object.entries(GRANTS).map(([name, scope]) => [
    name,
    {
      scope,
      // `ScopePermissions`: the granular permissions only.
      granular: outcomesFor(ScopePermissions, scope),
      // `ScopePermissionsTransition`: what the reference PDS constructs for
      // every OAuth credential.
      transition: outcomesFor(ScopePermissionsTransition, scope),
    },
  ]),
)

// --- 4. `ScopeMissingError` scope strings -----------------------------------

const missing = (() => {
  const p = new ScopePermissions('atproto')
  const needed = (fn, arg) => {
    try {
      fn.call(p, arg)
      return null
    } catch (err) {
      return err.scope ?? null
    }
  }
  return [
    { resource: 'repo', arg: { collection: 'app.bsky.feed.post', action: 'create' } },
    { resource: 'repo', arg: { collection: '*', action: 'delete' } },
    { resource: 'blob', arg: { mime: 'image/png' } },
    { resource: 'rpc', arg: { lxm: 'app.bsky.feed.getFeed', aud: 'did:web:example.com#bsky_fg' } },
    { resource: 'rpc', arg: { lxm: 'app.bsky.feed.getFeed', aud: '*' } },
    { resource: 'identity', arg: { attr: 'handle' } },
    { resource: 'identity', arg: { attr: '*' } },
    { resource: 'account', arg: { attr: 'email', action: 'read' } },
    { resource: 'account', arg: { attr: 'repo', action: 'manage' } },
  ].map(({ resource, arg }) => ({
    resource,
    arg,
    scope: needed(
      {
        repo: p.assertRepo,
        blob: p.assertBlob,
        rpc: p.assertRpc,
        identity: p.assertIdentity,
        account: p.assertAccount,
      }[resource],
      arg,
    ),
  }))
})()

// --- 5. `include:` expansion -------------------------------------------------

const permission = (resource, fields) => ({ type: 'permission', resource, ...fields })

const INCLUDES = [
  {
    // The permission set in https://atproto.com/specs/permission, with the
    // elided `lxm` list written out.
    name: 'specExample',
    scope: 'include:com.example.authBasicFeatures?aud=did:web:api.example.com%23svc_appview',
    permissions: [
      permission('repo', { collection: ['com.example.post'] }),
      permission('repo', { collection: ['com.example.like'], action: ['delete'] }),
      permission('rpc', {
        inheritAud: true,
        lxm: [
          'com.example.getFeed',
          'com.example.getProfile',
          'com.example.getPreferences',
          'com.example.putPreferences',
          'com.example.getAuthorFeed',
        ],
      }),
      permission('rpc', { aud: '*', lxm: ['com.example.getFeedSkeleton'] }),
    ],
  },
  {
    name: 'specExampleWithoutAudience',
    scope: 'include:com.example.authBasicFeatures',
    permissions: [
      permission('repo', { collection: ['com.example.post'] }),
      permission('rpc', { inheritAud: true, lxm: ['com.example.getFeed'] }),
      permission('rpc', { aud: '*', lxm: ['com.example.getFeedSkeleton'] }),
    ],
  },
  {
    name: 'wildcardsAreNotAllowedInASet',
    scope: 'include:com.example.authBasicFeatures?aud=did:web:api.example.com%23svc_appview',
    permissions: [
      permission('repo', { collection: ['*'] }),
      permission('repo', { collection: ['com.example.post', '*'] }),
      permission('rpc', { inheritAud: true, lxm: ['*'] }),
      permission('rpc', { aud: '*', lxm: ['*'] }),
    ],
  },
  {
    name: 'inheritAudAndAudTogether',
    scope: 'include:com.example.authBasicFeatures?aud=did:web:api.example.com%23svc_appview',
    permissions: [
      permission('rpc', { inheritAud: true, aud: '*', lxm: ['com.example.getFeed'] }),
      permission('rpc', {
        inheritAud: true,
        aud: 'did:web:api.example.com#svc_appview',
        lxm: ['com.example.getFeed'],
      }),
      permission('rpc', { inheritAud: false, aud: '*', lxm: ['com.example.getFeed'] }),
      permission('rpc', { inheritAud: false, lxm: ['com.example.getFeed'] }),
    ],
  },
  {
    name: 'resourcesThatMayNotAppearInASet',
    scope: 'include:com.example.authBasicFeatures',
    permissions: [
      permission('blob', { accept: ['image/*'] }),
      permission('account', { attr: 'email' }),
      permission('identity', { attr: 'handle' }),
      permission('include', { nsid: 'com.example.other' }),
      permission('space', { spaceType: 'com.example.group' }),
      permission('unknown', { collection: ['com.example.post'] }),
    ],
  },
  {
    name: 'unexpectedNamesAndValues',
    scope: 'include:com.example.authBasicFeatures',
    permissions: [
      permission('repo', { collection: ['com.example.post'], extra: 'property' }),
      permission('repo', { collection: 'com.example.post' }),
      permission('repo', { collection: [] }),
      permission('repo', { collection: ['com.example.post'], action: [] }),
      permission('repo', { collection: ['com.example.post'], action: 'create' }),
      permission('repo', { collection: ['com.example.post'], action: ['manage'] }),
      permission('repo', { collection: [1] }),
      permission('repo', { collection: [true] }),
      permission('repo', { collection: [['com.example.post']] }),
      permission('rpc', { aud: ['*'], lxm: ['com.example.getFeed'] }),
      permission('rpc', { aud: 1, lxm: ['com.example.getFeed'] }),
      permission('rpc', { aud: '*', lxm: 'com.example.getFeed' }),
      permission('rpc', { aud: '*', lxm: ['com.example.getFeed'], inheritAud: 'true' }),
      permission('repo', { collection: ['com.example.kept'] }),
    ],
  },
  {
    name: 'namespaceAuthority',
    scope: 'include:app.example.feed.authOnlyPost',
    permissions: [
      permission('repo', { collection: ['app.example.feed.post'] }),
      permission('rpc', { aud: '*', lxm: ['app.example.feed.getPostThread'] }),
      permission('repo', { collection: ['app.example.actor.profile'] }),
      permission('repo', { collection: ['app.example.feed.post', 'app.example.actor.profile'] }),
      permission('repo', { collection: ['app.example.feed.deeper.record'] }),
      permission('repo', { collection: ['app.example.record'] }),
      permission('repo', { collection: ['app.examplefeed.post.record'] }),
    ],
  },
  {
    name: 'namespaceAuthorityOneLevelUp',
    scope: 'include:app.example.authFull',
    permissions: [
      permission('repo', { collection: ['app.example.feed.post'] }),
      permission('rpc', { aud: '*', lxm: ['app.example.feed.getPostThread'] }),
      permission('repo', { collection: ['app.example.actor.profile'] }),
      permission('repo', { collection: ['app.other.actor.profile'] }),
      permission('repo', { collection: ['app.example.profile'] }),
    ],
  },
  {
    name: 'canonicalForm',
    scope: 'include:com.example.auth',
    permissions: [
      permission('repo', {
        collection: ['com.example.b', 'com.example.a', 'com.example.b'],
        action: ['delete', 'create', 'delete'],
      }),
      permission('repo', { collection: ['com.example.a'], action: ['delete', 'update', 'create'] }),
      permission('rpc', { aud: '*', lxm: ['com.example.b', 'com.example.a'] }),
    ],
  },
]

const includes = INCLUDES.map(({ name, scope, permissions }) => {
  const permissionSet = { type: 'permission-set', permissions }
  const result = call(() => IncludeScope.fromString(scope).toScopes(permissionSet))
  return { name, scope, permissionSet, scopes: result.value, threw: result.threw }
})

const AUTHORITY_CHECKS = [
  ['com.example.foo.auth', 'com.example.foo.identifier'],
  ['com.example.foo.auth', 'com.example.foo.bar.baz'],
  ['com.example.foo.auth', 'com.example.foo'],
  ['com.example.foo.auth', 'com.example.foo.'],
  ['com.example.foo.auth', 'com.example.foo.a'],
  ['com.example.foo.auth', 'com.example.fooo.a'],
  ['com.example.foo.auth', 'com.example.bar'],
  ['com.example.foo.auth', 'com.example'],
  ['com.example.foo.auth', 'com'],
  ['com.example.foo.auth', ''],
  ['com.example.foo.auth', '*'],
  ['com.example.foo.auth', 'com.example.foo.*'],
  ['com.example.foo.auth', 'com.example.foo.é'],
  ['com.example.foo.auth', 'com.example.foé'],
  ['com.example.foo.auth', 'COM.EXAMPLE.FOO.bar'],
  ['app.example.feed.authOnlyPost', 'app.example.feed.post'],
  ['app.example.feed.authOnlyPost', 'app.example.feed.getPostThread'],
  ['app.example.feed.authOnlyPost', 'app.example.actor.profile'],
  ['app.example.authFull', 'app.example.feed.post'],
  ['app.example.authFull', 'app.example.actor.profile'],
  ['app.example.authFull', 'app.other.actor.profile'],
]

const authority = AUTHORITY_CHECKS.map(([nsid, other]) => ({
  nsid,
  other,
  isParentAuthority: new IncludeScope(nsid).isParentAuthorityOf(other),
}))

// --- 6. Validators ------------------------------------------------------------

const DID_REFS = [
  'did:plc:z72i7hdynmk6r22z27h6tvur#service_id',
  'did:plc:asdf123#service_id',
  'did:plc:Z72I7HDYNMK6R22Z27H6TVUR#service_id',
  'did:plc:z72i7hdynmk6r22z27h6tvu1#service_id',
  'did:plc:z72i7hdynmk6r22z27h6tvur',
  'did:plc:z72i7hdynmk6r22z27h6tvur#',
  'did:plc:z72i7hdynmk6r22z27h6tvur#a#b',
  'did:plc:z72i7hdynmk6r22z27h6tvur#has/slash',
  'did:plc:z72i7hdynmk6r22z27h6tvur#has?question',
  'did:plc:z72i7hdynmk6r22z27h6tvur#has%20escape',
  'did:plc:z72i7hdynmk6r22z27h6tvur#has%2',
  'did:plc:z72i7hdynmk6r22z27h6tvur#has%zzescape',
  'did:plc:z72i7hdynmk6r22z27h6tvur#has space',
  'did:plc:z72i7hdynmk6r22z27h6tvur#!$&\'()*+,;=:@',
  'did:plc:z72i7hdynmk6r22z27h6tvur#a[b]',
  'did:plc:z72i7hdynmk6r22z27h6tvur#é',
  'did:example:456#service_id',
  'did:key:z6MkhaXgBZDvotDkL5257faiztiGiC2QtKLGpbnnEGta2doK#atproto',
  'not-a-did#frag',
  '#frag',
  '',

  // did:web
  'did:web:example.com#bsky_fg',
  'did:web:EXAMPLE.com#bsky_fg',
  'did:web:example.com:path#bsky_fg',
  'did:web:example.com:#bsky_fg',
  'did:web::example.com#bsky_fg',
  'did:web:#bsky_fg',
  'did:web:localhost#svc',
  'did:web:localhost%3A8080#svc',
  'did:web:localhost%3a8080#svc',
  'did:web:localhost%3A#svc',
  'did:web:localhost%3Aabc#svc',
  'did:web:localhost%3A99999#svc',
  'did:web:localhost%3A8080%3A9090#svc',
  'did:web:localhost:8080#svc',
  'did:web:localhostx%3A8080#svc',
  'did:web:example.com%3A8443#svc',
  'did:web:ex%ample.com#svc',
  'did:web:example.com%#svc',
  'did:web:example.com%4#svc',
  'did:web:%41.com#svc',
  'did:web:%61.com#svc',
  'did:web:ex%2Dample.com#svc',
  'did:web:example.com%2Fpath#svc',
  'did:web:example.com%3Fquery#svc',
  'did:web:example.com%40host#svc',
  'did:web:exa%20mple.com#svc',
  'did:web:%C3%A9xample.com#svc',
  'did:web:example..com#svc',
  'did:web:.example.com#svc',
  'did:web:example.com.#svc',
  'did:web:.#svc',
  'did:web:-example.com#svc',
  'did:web:exa_mple.com#svc',
  'did:web:xn--bcher-kva.example#svc',
  'did:web:xn--a.example#svc',
  'did:web:xn--.example#svc',
  'did:web:1.2.3.4#svc',
  'did:web:1.2.3.4.5#svc',
  'did:web:1.2.3.256#svc',
  'did:web:999999999999#svc',
  'did:web:0x7f.1#svc',
  'did:web:foo.123#svc',
  'did:web:foo.0x1#svc',
  'did:web:foo.1a#svc',
  'did:web:123.foo#svc',
]

const didRefs = DID_REFS.map((input) => ({
  input,
  isAtprotoDidRefAbsolute: isAtprotoDidRefAbsolute(input),
}))

const NSIDS = [
  'com.example.foo',
  'com.example.fooBar',
  'com.example.foo1',
  'com.example.1foo',
  'com.example.foo-bar',
  'com.example-.foo',
  'com.-example.foo',
  'com.ex-ample.foo',
  'com.9example.foo',
  'com.example9.foo',
  '9com.example.foo',
  'c9m.example.foo',
  '-com.example.foo',
  'com.example',
  'com',
  'a.b.c',
  'a.b.c.d.e.f',
  'com.example.Foo',
  'COM.EXAMPLE.foo',
  'com.example.foo.',
  '.com.example.foo',
  'com..foo',
  'com.example.foo_bar',
  'com.example.f',
  'com.example.*',
  '*',
  '',
  'com.exa mple.foo',
  'com.exämple.foo',
  `com.${'a'.repeat(63)}.foo`,
  `com.${'a'.repeat(64)}.foo`,
  `com.example.${'a'.repeat(63)}`,
  `com.example.${'a'.repeat(64)}`,
  `${Array.from({ length: 4 }, () => 'a'.repeat(63)).join('.')}.${'b'.repeat(61)}.foo`,
  `${Array.from({ length: 4 }, () => 'a'.repeat(63)).join('.')}.${'b'.repeat(62)}.foo`,
]

const nsids = NSIDS.map((input) => ({ input, isNsid: isNsid(input) }))

const ACCEPTS = [
  '*/*',
  'image/*',
  'image/png',
  'IMAGE/PNG',
  'image/svg+xml',
  'application/vnd.api+json',
  'image//png',
  '/png',
  'image/',
  'image/**',
  '*/png',
  '*',
  'image',
  'image/png/extra',
  'image/ png',
  'im*ge/*',
  '*a/*',
  'im*ge/png',
  'image/p*g',
  '',
]

const accepts = ACCEPTS.map((input) => ({
  input,
  isAccept: isAccept(input),
  isMime: isMime(input),
}))

// --- 7. The two serialisers --------------------------------------------------

const ENCODER_INPUTS = [
  'a~b', 'a+b', 'a b', 'a,b', 'a:b', 'a/b', 'a@b', 'a%b', 'a&b', 'a=b', 'a#b',
  'a?b', "a!b", "a'b", 'a(b)', 'a*b', 'a-b_c.d', 'é', '☺️',
]

const encoders = ENCODER_INPUTS.map((raw) => ({
  raw,
  encodeURIComponent: encodeURIComponent(raw),
  urlSearchParams: new URLSearchParams([['x', raw]]).toString().slice(2),
}))

process.stdout.write(
  JSON.stringify(
    {
      $comment:
        'Generated by running @atproto/oauth-scopes unbuilt at referenceCommit. Do not hand-edit: run Tests/PetrelOAuthScopesTests/UpstreamGoldens/regenerate.sh.',
      referenceRepository: 'https://github.com/bluesky-social/atproto',
      referenceCommit: REFERENCE_COMMIT,
      source: 'packages/oauth/oauth-scopes',
      values,
      strings,
      matches,
      missing,
      includes,
      authority,
      didRefs,
      nsids,
      accepts,
      encoders,
    },
    null,
    2,
  ) + '\n',
)
