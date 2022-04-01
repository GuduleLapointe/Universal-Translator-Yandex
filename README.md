# Universal Translator (Yandex Edition)

## Important note:

As noted by sninksnoodle on Oct 27, 2020, Yandex does not provide free API keys anymore. The main goal of this fork was to provide an free alternative to Google Translate, so the project is now obolete.

However, this code also fixed a couple of bugs in the available version of Hank Hamos Universal Translator (which dates 2015), so it might be worth to catch and bring these fixes to the Google Translate version.

## Original readme

- Authors: ©2016 Gudule Lapointe gudule@speculoos.world
- Based on Universal Translator 1.9.0 (Google) ©2006-2009 Hank Ramos
- License: AGPLv3
- Source: <https://git.magiiic.com/opensimulator/Universal-Translator-Yandex>

It is based on the excellent Universal Translator by Hank Ramos. However, the initial version was using Google translation engine API and Google decided to switch to a paid license. So I rewrote some parts of the code to use Yandex engine instead.

Get the latest version in Speculoos' grid speculoos.world:8002:Lab or on the git repository <https://git.magiiic.com/opensimulator/Universal-Translator-Yandex> (and if you make improvements, please share them there)

# New features

- It's working! No kidding: the version available on LSL scripts wiki and on other sites like Outworldz is incomplete and not ready to work, even taking apart the Google license issue.
- Use Yandex translation API. It is not only free (while Google isn't anymore), but it is easy to get an API key (while it's quite complicate with Google or Microsoft API's).
- The API key is not hardcoded but instead stored in a notecard. This avoids a single key being spread everywhere and causing "maximum allowed requests reached" kind of messages.

DO NOT DISTRIBUTE THE TRANSLATOR WITH THE API KEY. It could end up being used by dozens of users, and becoming useless.

# Main (and not so new) features

- Multiplex mode: if several translators are in the same area, one becomes the master and makes actual translation requests for the other ones. This avoid overload when lot of people are present and using it.
- Speaker language auto detection (though users can also choose their language manually)
- Translations sent by instant messages, no spam on the public channel
- Can be used as an object in the parcel or as a HUD.
- Can use both an object in the parcel and people wearing HUD, without spamming public channel, nor overloading the servers and the API key limits.

# To do

- Get an updated list of available languages ✓ A (beautiful) texture and logo
- Detect the most used languages and show them at beginning of the list
- Allow to set a fixed list of preferred languages to show first (probably before the auto-detected mostly used ones).

# Notes

We use a dedicated function json2List instead of llJson2List (not compatible with 0.8). It's a little bit rough, but it works.
