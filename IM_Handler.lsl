/*
 * Universal Translator (Yandex) - IM Handler
 *   Part of Universal Translator (Yandex)
 * Version: Yandex-1.2
 * Authors: ©2016 Gudule Lapointe gudule@speculoos.world
 *          Based on Universal Translator 1.9.0 (Google) ©2006-2009 Hank Ramos
 * License: AGPLv3
 * Source: https://git.magiiic.com/opensimulator/Universal-Translator-Yandex
 */

debug(string message)
{
    llOwnerSay("/me ("  + llGetScriptName() + "): " + message);
}

default
{
    state_entry()
    {
//        llListen(85234119, "", NULL_KEY, "");
//        llListen(85304563, "", NULL_KEY, "");
    }
    link_message(integer sender_num, integer num, string str, key id)
    {
        if(num == 85234119 || num == 85304563)
        {
            string name = llGetObjectName();
            string tempName = llGetSubString(str, 0, llSubStringIndex(str, ":") - 1);
            string tempMessage = llGetSubString(str, llSubStringIndex(str, ":") + 2, -1);
            llSetObjectName(tempName);
            llInstantMessage(id, tempMessage);
            llSetObjectName(name);
        }
    }
    listen(integer channel, string name, key id, string message)
    {
        debug("got message "
            + "\nchannel " + (string)channel
            + "\nname " + name
            + "\nid " + (string)id
            + "\nmessage " + message
        );
    }
}
