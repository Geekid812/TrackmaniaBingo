## Bingo Technical Previews
Are you looking to help test the latest and most bleeding edge bingo versions? This document will guide you through the steps to install development versions, and you'll also learn how to help out by reporting bugs or other problems.

## Prerequisites
Club Access is required to use the Technical Previews! This is because it is required in order to run unsigned plugins in Openplanet. [Read why this is a requirement here.][opclub]

### Download the plugin source
There are two different ways to do get the plugin's source code. Generally the recommended way is to use `git`, especially if you intend to do plugin development, as the tool will automatically manage versions for you. Here's the link to download [Git for Windows][gitwin]. If you don't want to install fancy software, you'll have to work with zip archives.

#### Using `git`
- Open a terminal or command prompt
- Navigate to your plugin folder using `cd C:/Users/YOUR_USERNAME/OpenplanetNext/Plugins`
- Type `git clone https://github.com/Geekid812/TrackmaniaBingo` to download the repository in a folder called `TrackmaniaBingo`
- Enter the directory (`cd TrackmaniaBingo`)
- Switch to the preview version using `git checkout preview`. You're ready to go!

#### Using zip archives
- Download the latest [preview version build][previewdl] from the website.
- Extract the archive to your plugins folder: `C:/Users/YOUR_USERNAME/OpenplanetNext/Plugins`
- Make sure that inside this `Plugins` folder there is now a `TrackmaniaBingo-preview` folder. If that is the case, then you're done!

### Enable Openplanet Developer mode
In order to run unsigned plugins, you need to turn on [Developer Mode][opdev] in the Openplanet settings.

To enable developer mode *temporarily*, go to `Developer -> Signature Mode -> Developer` in the Openplanet Menu.
To enable developer mode *permanently*, go to `Openplanet -> Settings -> Script engine -> Enable developer mode on startup` in the Openplanet Menu.

That's it! You can now play Bingo in Preview mode! To make sure you don't mix up the official and the preview version, we recommend disabling the official version in the Openplanet settings while you are working on the preview.

## How to report issues
As a early tester for new versions of bingo, any problem you discover and report to the development team can enable us to patch the issue before some random person gets really mad at the plugin for not working correctly!

If you are already in our [Discord server][discord], you can send a report in the `#developement` channel detailing how you encountered the issue. Otherwise, you can also [open an issue][newissue] in the repository. In that case, make sure to add the `preview` label to your issue! In any case, we recommend uploading your `Openplanet.log` file as an attachment to make it easier to find the cause of the problem.

[opclub]: https://openplanet.dev/next/club
[gitwin]: https://git-scm.com/download/win
[previewdl]: https://github.com/Geekid812/TrackmaniaBingo/archive/refs/heads/preview.zip
[opdev]: https://openplanet.dev/news/2022/developer-mode
[discord]: https://discord.gg/pJbeqptsEa
[newissue]: https://github.com/Geekid812/TrackmaniaBingo/issues/new/choose