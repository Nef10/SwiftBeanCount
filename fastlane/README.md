fastlane documentation
================
# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```
xcode-select --install
```

Install _fastlane_ using
```
[sudo] gem install fastlane -NV
```
or alternatively using `brew cask install fastlane`

# Available Actions
## Mac
### mac test
```
fastlane mac test
```
Run tests
### mac dependencies
```
fastlane mac dependencies
```
Install dependencies
### mac lint
```
fastlane mac lint
```
Run linter
### mac coverage_report
```
fastlane mac coverage_report
```
Code coverage report
### mac pr_comment
```
fastlane mac pr_comment
```
Danger comment on PR
### mac coverage
```
fastlane mac coverage
```
Test and gather coverage report
### mac ci
```
fastlane mac ci
```
Test, lint and run danger for coverage comment

----

This README.md is auto-generated and will be re-generated every time [fastlane](https://fastlane.tools) is run.
More information about fastlane can be found on [fastlane.tools](https://fastlane.tools).
The documentation of fastlane can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
