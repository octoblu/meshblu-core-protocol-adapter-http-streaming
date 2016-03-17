semver      = require 'semver'
packageJSON = require '../package.json'

describe 'Node.JS', ->
  it 'should be the correct version', ->
    actualVersion = process.version
    expectedVersion = packageJSON.engines.node

    errorMessage = "Node #{actualVersion} does not satisfy #{expectedVersion}"
    expect(semver.satisfies(actualVersion, expectedVersion)).to.equal true, errorMessage
