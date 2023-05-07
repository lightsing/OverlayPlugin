# If you're familiar with Chromium or other Google projects:
#   Sorry, this file actually has nothing to do with gclient.
#   I just borrowed the basic concept and naming scheme.

deps = {
    'ACT': {
        'url': 'https://github.com/EQAditu/AdvancedCombatTracker/releases/download/3.4.9.271/ACTv3.zip',
        'dest': 'Thirdparty/ACT',
        'strip': 0,
        'hash': ['sha256', 'eb5dc7074c32a534d4e80e0248976c9499c377b61892be2ae85ad631e5af6589'],
    },
    'FFXIV_ACT_Plugin': {
        'url': 'https://github.com/ravahn/FFXIV_ACT_Plugin/raw/master/Releases/FFXIV_ACT_Plugin_SDK_2.0.6.1.zip',
        'dest': 'Thirdparty/FFXIV_ACT_Plugin',
        'strip': 0,
        'hash': ['sha256', 'ed98fa01ec2c7ed2ac843fa8ea2eec1d66f86fad4c6864de4d73d5cfbf163dce'],
    },
    'FFXIVClientStructs': {
        'url': 'https://github.com/aers/FFXIVClientStructs/archive/e02acce27a77f47c9076c19ad89609127fa36c30.zip',
        'dest': 'OverlayPlugin.Core/Thirdparty/FFXIVClientStructs/Base/Global',
        'strip': 1,
        'hash': ['sha256', 'f9ec36ec8caa15047d13e18e1e1d2beee4d50e93b42d4d822e858931b92b5958'],
    },
}
