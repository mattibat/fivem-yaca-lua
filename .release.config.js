module.exports = {
  branches: ['main'],
  tagFormat: 'v${version}',

  plugins: [
    '@semantic-release/commit-analyzer',

    '@semantic-release/release-notes-generator',

    [
      '@semantic-release/changelog',
      {
        changelogFile: 'CHANGELOG.md',
      },
    ],

    [
      '@semantic-release/exec',
      {
        prepareCmd:
          'node .github/actions/bump-manifest-version.js ${nextRelease.version}',
      },
    ],

    [
      '@semantic-release/git',
      {
        assets: ['CHANGELOG.md', 'fxmanifest.lua'],
        message: 'chore(release): ${nextRelease.version} [skip ci]',
      },
    ],

    [
      '@semantic-release/github',
      {
        assets: [
          {
            path: 'yaca-voice.zip',
            label: 'Download ZIP',
          },
        ],
      },
    ],
  ],
};