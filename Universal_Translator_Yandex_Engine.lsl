/*
 * Universal Translator (Yandex)
 *
 * Version: Yandex-1.2
 * Authors: ©2016 Gudule Lapointe gudule@speculoos.world
 *          Based on Universal Translator 1.9.0 (Google) ©2006-2009 Hank Ramos
 * License: AGPLv3
 * Source: https://git.magiiic.com/opensimulator/Universal-Translator-Yandex
 *
 * Web Server Services powered by Yandex (instead of Google in the initial
 * version),as Google switched to a paid license for their translation API.
 */

//Variables
list agentsInTranslation;
list agentsInTranslationOptions;
list requestList;
integer listenID;

integer isMaster = 1;
integer autoLanguage = TRUE;
integer enabled = FALSE;
integer showTranslation = FALSE;
integer tranObjects = TRUE;

integer lastHeartBeat;

list languageFavorites = [
    "en", "sp", "fr",
    "pt", "it", "nl",
    "de", "ru", "ar"
];
list    languageCodes = [
"zh-CN", "zh-TW", "hr",
"bg", "be", "ca",
"af", "sq", "ar",

"tl", "fr", "gl",
"fi", "en", "et",
"cs", "da", "nl",

"id", "ga", "it",
"hi", "hu", "is",
"de", "el", "iw",

"mt", "no", "fa",
"lt", "mk", "ms",
"ja", "ko", "lv",

"sl", "es", "sw",
"ru", "sr", "sk",
"pl", "pt", "ro",

"yi", "", "",
"uk", "vi", "cy",
"sv","th", "tr"];

list    translators;
list    sayCache;
list    sayCachePrivate;
integer priorityNumber;
integer priorityNumListenID;
integer isInitialized = FALSE;
string  options;
integer dialogChannel;
key requestKey;
string apiKey;
string apiUrl = "https://translate.yandex.net/api/v1.5/tr"; //"https://translate.yandex.net/api/v1.5/tr/translate?key=";
//"https://translate.yandex.net/api/v1.5/tr.json/detect"?
string baseurl;

//Options
//integer debug = TRUE;
integer broadcastChannel = -9999999; //note this is not the channel used by the HR Universal Translator
string  password = "password"; //note this is not the password used to encrypt comms of the HR Universal Translator
integer version = 190;

sendIM(key id, string str)
{
    if (llGetParcelFlags(llGetPos()) & PARCEL_FLAG_ALLOW_SCRIPTS)
    {
        //debug("send to all " + str + " id " + id);
        llMessageLinked(LINK_ALL_CHILDREN, 85234119, str, id);
        llMessageLinked(LINK_THIS, 85304563, str, id);
    }
    else
    {
        //debug("send to myself");
        llMessageLinked(LINK_THIS, 85304563, str, id);
    }
}

sendTextBatch(integer channel, string sendText)
{
    sendText = llXorBase64StringsCorrect(llStringToBase64(sendText), llStringToBase64(password));;
    while (llStringLength(sendText) > 508) //If string is 509 characters or longer
    {
        llSay(channel, llGetSubString(sendText, 0, 507)); //send 508 character chunk
        sendText = llGetSubString(sendText, 508, -1);  //delete 508 character chunk
    }
    llSay(channel, sendText);  //send out any remainder chunk or original chunk
    if (llStringLength(sendText) == 508)
        llSay(channel, (string)(channel*4958654));
    llMessageLinked(LINK_ALL_CHILDREN, 6634934, (string)<0.25, 0, 0.25>, "");
}

string receiveTextBatch(key id, string message)
{
    integer listPos;
    string  tempString = "";

    listPos = llListFindList(sayCache, [id]);
    if (listPos >= 0)
    {
        while (listPos >= 0)
        {
            tempString = tempString + llList2String(sayCache, listPos + 1);
            sayCache = llDeleteSubList(sayCache, listPos, listPos + 1);
            listPos = llListFindList(sayCache, [id]);
        }
        message = tempString + message;
    }
    message = llBase64ToString(llXorBase64StringsCorrect(message, llStringToBase64(password)));
    return message;
}
string receiveTextBatchPrivate(key id, string message)
{
    integer listPos;
    string  tempString = "";

    listPos = llListFindList(sayCachePrivate, [id]);
    if (listPos >= 0)
    {
        while (listPos >= 0)
        {
            tempString = tempString + llList2String(sayCachePrivate, listPos + 1);
            sayCachePrivate = llDeleteSubList(sayCachePrivate, listPos, listPos + 1);
            listPos = llListFindList(sayCachePrivate, [id]);
        }
        message = tempString + message;
    }
    message = llBase64ToString(llXorBase64StringsCorrect(message, llStringToBase64(password)));
    return message;
}
updateTranslatorList()
{
    integer x;
    integer listLength;
    list    newList;
    string  tempString;
    integer newMaster;

    //Scan and remove translators not in the area
    for (x = 0; x < llGetListLength(translators); x += 2)
    {
        tempString = llList2String(llGetObjectDetails(llList2Key(translators, x + 1), [OBJECT_POS]), 0);
        if ((llVecDist(llGetPos(), (vector)tempString) <= 20.0) && (tempString != ""))
            newList += llList2List(translators, x, x + 1);
    }
    translators = newList;

    listLength = llGetListLength(translators);
    llMessageLinked(LINK_THIS, 65635544, (string)listLength, "");

    if (listLength == 0)
    {
        newMaster = 1;
    }
    else
    {
        if (enabled)
        {
            newMaster = 2;
            for (x = 0; x < llGetListLength(translators); x += 2)
            {
                //llOwnerSay("Checking Priority Number(" +  (string)priorityNumber + "): " + (string)llList2Integer(translators, x));
                if (llList2Integer(translators, x) > priorityNumber)
                {
                    newMaster = 0;
                }
            }
        }
        else
        {
            newMaster = 0;
        }
    }

    if ((isMaster > 0) && (newMaster == 0))
    {
        //We are being demoted from master to slave
        //Flush agentsInTranslation to master
        if (llGetListLength(agentsInTranslation) > 0)
        {
            //Demotion Dump of agentsInTranslation to Master
            sendTextBatch(broadcastChannel, llList2CSV([1003, llList2CSV(agentsInTranslation)]));
            if (isInitialized == FALSE) return;
            sendTextBatch(broadcastChannel, llList2CSV([1004, options])); //error
        }
        llListenRemove(listenID);
    }
    if ((isMaster == 0) && (newMaster > 0))
    {
        llListenRemove(listenID);
        listenID = llListen(0, "", "", "");
    }
    isMaster = newMaster;
    llMessageLinked(LINK_THIS, 34829304, (string)isMaster, "");
}

sendHeartbeat()
{
    updateTranslatorList();
    sendTextBatch(broadcastChannel, llList2CSV([1001, priorityNumber]));

    //Broadcast agentList to Slaves
    if (isMaster == 2)
    {
        sendTextBatch(broadcastChannel, llList2CSV([1002, llList2CSV(agentsInTranslation)]));
    }

}

//Functions
checkThrottle(integer num, string msg, list params)
{
    integer x;
    integer maxCount;
    float   oldTime;
    float   sleepTime;
    list    newList;
    key     returnValue;
    integer channelToSpeak;
    //loop though list and remove items older than 25 seconds
    for (x = 0; x < llGetListLength(requestList); x += 1)
    {
        oldTime = llList2Float(requestList, x);
        //Construct new list with only times less than 25 seconds
        if ((llGetTime() - oldTime) <= 25.0)
            newList += oldTime;
    }
    requestList = newList;

    x = llGetListLength(requestList);

    //Shunt all translations to linked translators if master
    if (isMaster == 2)
    {
        if (num == 0)
        {
            //Send HTTP request to other translator
            //Send out Request to Random Translator Channel

            channelToSpeak = llList2Integer(llListRandomize(llList2ListStrided(translators, 0, -1, 2), 1), 0);
            if (channelToSpeak > 0)
            {
                sendTextBatch(channelToSpeak, llList2CSV([num, llList2CSV(params)]) + "~" + msg);
                return;
            }
        }
    }

    if (x == 19)
    {
        sleepTime =  25.0 - (llGetTime() - llList2Float(requestList, 0));
        if (sleepTime > 0)
        {
            llSleep(sleepTime);
        }
        requestList = llDeleteSubList(requestList, 0, 0);
    }
    string requestUrl;

    if (num == 0)
    {
        string speakerLanguage = llGetSubString(msg, llSubStringIndex(msg, "&langpair") + 13, -1);
        //strReplace
        string langpair=strReplace(llList2String(params, 3), "|", "-");
        msg = llGetSubString(msg, 0, llSubStringIndex(msg, "&langpair"));
        requestUrl = "https://translate.yandex.net/api/v1.5/tr.json/translate?key="
         + apiKey + "&text=" + msg + "&lang=" + langpair;
         // langpair
/*        msg = "translate?key=" + apiKey
            + "&fromlang=en"
            + "&tolang=fr";
*/
    }
    else
    {
        requestUrl = "https://translate.yandex.net/api/v1.5/tr.json/detect?key=" + apiKey + "&text=" + msg;
        msg = ".json/dectect?key=" + apiKey + "&text=" + msg;
//        msg = "detect?v=1.0&q=" + msg;
    }
    requestList += llGetTime();
    returnValue = llHTTPRequest(requestUrl, [HTTP_METHOD, "GET", HTTP_MIMETYPE, "plain/text;charset=utf-8"], "");

    if (returnValue != NULL_KEY)
    {
        if (num == 0)
        {
            llMessageLinked(LINK_THIS, 235365342, llList2CSV(params), returnValue);
        }
        else
            llMessageLinked(LINK_THIS, 235365343, llList2CSV(params), returnValue);
    }
    else
    {
        llSleep(40.0); //Something has gone horribly wrong, sleep 40 seconds to clear throttle
    }
}

string checkLanguage(string tempString)
{
    if      (llGetSubString(tempString, 0, 1) == "zh")    tempString = "zh-CN";
    else if (tempString == "und")   tempString = "el";
    else if (llListFindList(languageCodes, [tempString]) < 0) tempString = "";
    tempString = llGetSubString(tempString, 0, 1);
    return tempString;
}
addAgent(key id, string language, integer recheckLangauge)
{
    integer listPos;
    integer listPosID;
    integer idNum;
    string  tempString;

    listPos = llListFindList(agentsInTranslation, [id]);
    if (listPos < 0)
    {
        while (listPosID >= 0)
        {
            idNum = llRound(llFrand(2000000)) + 1;
            listPosID = llListFindList(agentsInTranslation, [idNum]);
        }
        agentsInTranslation += [id, language, recheckLangauge, idNum];
        llMessageLinked(LINK_THIS, 64562349, language, id);
    }
    else
        agentsInTranslation = llListReplaceList(agentsInTranslation, [language, recheckLangauge], listPos + 1, listPos + 2);
}

string addNewAgent(key id)
{
    string speakerLanguage;

    if (llList2Key(llGetObjectDetails(id, [OBJECT_CREATOR]), 0) == NULL_KEY)
    {
        speakerLanguage  = checkLanguage(llGetAgentLanguage(id));
        if (speakerLanguage == "")
        {
            speakerLanguage = "en";
            addAgent(id, speakerLanguage, TRUE);
        }
        else
        {
            addAgent(id, speakerLanguage, FALSE);
        }
    }
    return speakerLanguage;
}

key getAgentKey(integer agentID)
{
    integer listPos = llListFindList(agentsInTranslation, [agentID]);
    if (listPos < 0)
    {
        return "";
    }
    else
    {
        return llList2Key(agentsInTranslation, listPos - 3);
    }
}
processHTTPResponse(integer type, string body, list params)
{
    integer listPos;
    list    recepientList;
    key     recepientID;
    string  recepientLanguage;
    string  languagePair;
    key     speakerID;
    string  speakerName;
    string  speakerLanguage;
    string  translatedText;
    string  tempString;
    integer x;
    integer speakerLanguageReliable;
    float   speakerLanguageConfidence;
    list    tempList;

    if(speakerID = NULL_KEY) speakerID = llList2Key(params, 1);
    speakerName = llKey2Name(speakerID);
    if(llSubStringIndex(speakerName, "@") > 0)
        speakerName = llGetSubString(speakerName, 0, llSubStringIndex(speakerName, "@") - 1);
    speakerName = llStringTrim(strReplace(speakerName, ".", " "), STRING_TRIM);

    //===================
    //Process Translation
    //===================
    if (type == 0)
    {
        if (speakerName == "")
            speakerName = llList2String(llGetObjectDetails(speakerID, [OBJECT_NAME]), 0);
        recepientList = llParseString2List(llList2String(params, 2), ["@"], []);
        tempList = llParseStringKeepNulls(llList2String(params, 3), ["|"],[]);

        recepientLanguage = llList2String(tempList, 1);
        languagePair = llDumpList2String(tempList, ">");
        //Perform Text Cleanup
        //x = llSubStringIndex(body, "\",\"detectedSourceLanguage\":\"");
        x = llSubStringIndex(body, "\"]}"); //"
        list json = json2List(body);
        if(llList2String(json, 0) == "code")
        {
            translatedText = llList2String(json, 5);
            languagePair = strReplace(llList2String(json, 3), "-", ">");
            speakerLanguage = llGetSubString(languagePair, 0, llSubStringIndex(languagePair, "-") - 1);
            listPos = llListFindList(agentsInTranslation, [speakerID]);
            if (listPos >= 0)
            {
                if (speakerLanguage != llList2String(agentsInTranslation, listPos + 1))
                    agentsInTranslation = llListReplaceList(agentsInTranslation, [TRUE], listPos + 2, listPos + 2);  //Mark for recheck of actual spoken language.
            }
        } else
        if (x >= 0)
        {
            //translatedText  = llGetSubString(body,  llSubStringIndex(body, "{\"translatedText\":\"") + 18, x);
            translatedText  = llGetSubString(body,  llSubStringIndex(body, "\"text\":[\"") + 9, x); //"
            //speakerLanguage = checkLanguage(llGetSubString(body, x + 28, llSubStringIndex(body, "\"}, \"responseDetails\":") - 1));
            speakerLanguage = llList2String(languagePair, 0);

            listPos = llListFindList(agentsInTranslation, [speakerID]);
            if (listPos >= 0)
            {
                if (speakerLanguage != llList2String(agentsInTranslation, listPos + 1))
                    agentsInTranslation = llListReplaceList(agentsInTranslation, [TRUE], listPos + 2, listPos + 2);  //Mark for recheck of actual spoken language.
            }
        }
        else
        {
            translatedText = llGetSubString(body, llSubStringIndex(body, "{\"translatedText\":\"") + 18, llSubStringIndex(body, "\"}, \"responseDetails\""));
        }

        //Reverse order if Recepient Language is Hebrew or Arabic
        if ((recepientLanguage == "iw") || (recepientLanguage == "ar"))
        {
            tempString = "";
            for(x = llStringLength(translatedText);x >= 0; x--)
            {
                tempString += llGetSubString(translatedText, x, x);
            }
            translatedText = tempString;
        }
        tempString = speakerName + " (" + languagePair + "): " + translatedText;
        if (showTranslation)
            sendIM(speakerID, tempString);
        for (x = 0; x < llGetListLength(recepientList); x += 1)
        {
            recepientID = getAgentKey(llList2Integer(recepientList, x));
            if (recepientID != "")
            {
                recepientLanguage = llList2String(agentsInTranslation, llListFindList(agentsInTranslation, [recepientID]) + 1);
                if (recepientLanguage != speakerLanguage)
                {
                    sendIM(recepientID, tempString);
                }
            }
        }
        return;
    }

    //===========================
    //Process Language Detection
    //===========================
    if (type == 1)
    {
        speakerID = llList2Key(params, 1);

//        speakerLanguageReliable = llToLower(llGetSubString(body, llSubStringIndex(body, "\",\"isReliable\":") + 15, llSubStringIndex(body, ",\"confidence\":") - 1)) == "true";
//        speakerLanguageConfidence = (float)llGetSubString(body, llSubStringIndex(body, ",\"confidence\":") + 14, llSubStringIndex(body, "}, \"responseDetails\":") - 1);
        // "
        speakerLanguageReliable = TRUE;
        speakerLanguageConfidence = 0.5;
        listPos = llListFindList(agentsInTranslation, [speakerID]);

        if (((listPos < 0) && (speakerLanguageReliable) || (speakerLanguageConfidence >= 0.18)))
        {
            //Analyze Data
            tempList = json2List(body);
//            tempString = checkLanguage(llToLower(llGetSubString(body, llSubStringIndex(body, "\"lang\":\"") + 8, llSubStringIndex(body, "\"}") - 1)));

            if (tempString == "")
                tempString = checkLanguage(llToLower(llList2String(tempList, 3)));
            if (tempString == "") return;

            if (speakerLanguageConfidence < 0.14)
                addAgent(speakerID, tempString, TRUE);
            else
                addAgent(speakerID, tempString, FALSE);
        }
    }
}

checkApi()
{
    if(llGetInventoryKey("Yandex API Key")!=NULL_KEY)
    {
        requestKey = llGetNotecardLine("Yandex API Key", 0);
    } else {
        llDialog(llGetOwner(), "API key not set.", ["Get key", "Save key"], dialogChannel);
    }
}

string trimQuotes(string str)
{
    str = llStringTrim(str, STRING_TRIM);
    if (llGetSubString(str, 0, 0) == "[")
        str = llDeleteSubString(str, 0, 0);
    if (llGetSubString(str, 0, 0) == "\"") //"
        str = llDeleteSubString(str, 0, 0);
    if (llGetSubString(str, -1, -1) == "]")
        str = llGetSubString(str, 0, llStringLength(str) - 2);
    if (llGetSubString(str, -1, -1) == "\"") //"
        str = llGetSubString(str, 0, llStringLength(str) - 2);
    str = llStringTrim(str, STRING_TRIM);
    return str;
}
list json2List(string json)
{
    list convertedList;
    list tempList;
    json = llGetSubString(json, 1, llStringLength(json) - 2);
    tempList = llParseString2List(json, [",\""], []); //"
    integer i = 0;
    do {
        string pair = llList2String(tempList, i);
        convertedList += [ trimQuotes(llGetSubString(pair, 0, llSubStringIndex(pair, ":") -1)) ];
        convertedList += [ trimQuotes(llGetSubString(pair, llSubStringIndex(pair, ":") + 1, -1)) ];
        i++;
    } while (i < llGetListLength(tempList));
    return convertedList;
}

string strReplace(string str, string search, string replace) {
    return llDumpList2String(llParseStringKeepNulls((str),[search],[]),replace);
}

debug(string message)
{
    llOwnerSay("/me ("  + llGetScriptName() + "): " + message);
}

default
{
    state_entry()
    {
        llSetText("Set API key", <1,1,1>, 1);
        dialogChannel = (integer) (llFrand(-1000000000.0) - 1000000000.0);
        llListen(dialogChannel, "", llGetOwner(), "");
        checkApi();
    }

    touch_start(integer num)
    {
        key id = llDetectedKey(0);
        if (id == llGetOwner()) checkApi();
    }

    changed(integer change)
    {
        if (change & CHANGED_INVENTORY)
        {
            checkApi();
        }
    }

    dataserver(key query_id, string data)
    {
        if (query_id == requestKey && data != "")
        {
            apiKey = data;
            baseurl = apiUrl + apiKey;
            state running;
        } else {
            llDialog(llGetOwner(), "API key not set.", ["Get key", "Save key"], dialogChannel);
        }
    }

    listen(integer channel, string name, key id, string message)
    {
        if(id != llGetOwner()) return;
        if(channel == dialogChannel)
        {
            if(message == "Get key")
            {
                llLoadURL(llGetOwner(), "Get a Yandex API key", "https://tech.yandex.com/keys/get/?service=trnsl");
                llOwnerSay("Visit  https://tech.yandex.com/keys/get/?service=trnsl to get an API key and save it in a notecard named 'Yandex API Key'");
            } else if(message == "Save key")
            {
                llTextBox(llGetOwner(),"Enter the API key",channel);
            } else {
                apiKey = message;
                baseurl = apiUrl + apiKey;
                llOwnerSay("The API key has been set, but it will be lost at next script restart.\nTo keep it, save it in a notecard named 'Yandex API Key'\nand put this notecard alongside the script.");
                state running;
            }
        }
    }
}

state running
{
    state_entry()
    {
        //Multiplexor Initialization
        priorityNumber = version*1000000 + llRound(llFrand(499999) + 50000);
        llListen(broadcastChannel, "", NULL_KEY, "");
        priorityNumListenID = llListen(priorityNumber, "", NULL_KEY, "");

        //Send out initial heartbeat
        lastHeartBeat = llGetUnixTime();
        sendTextBatch(broadcastChannel, llList2CSV([1001, priorityNumber]));

        //Wait for the network to settle down
        llSetTimerEvent(5);
        //llSetTimerEvent(10 + ((1-llGetRegionTimeDilation()) * 1));
    }

    sensor(integer num_detected)
    {
        integer x;
        key     id;

        for (x = 0; x < num_detected; x += 1)
        {
            id = llDetectedKey(x);
            if (llListFindList(agentsInTranslation, [id]) < 0)
            {
                addNewAgent(id);
            }
        }
    }
    link_message(integer sender_num, integer num, string str, key id)
    {
        integer x;
        integer listPos;
        list    tempList;
        integer channelToSpeak;

        //Old Multiplexor
        if (num == 8434532)
        {
            enabled = (integer)str;
        }
        else if (num == 3342976)
        {
            //Send Preferences
            options = str;
            if (isInitialized == FALSE) return;
            tempList = llCSV2List(options);
            showTranslation = llList2Integer(tempList, 0);
            tranObjects = llList2Integer(tempList, 1);
            autoLanguage = llList2Integer(tempList, 2);
            sendTextBatch(broadcastChannel, llList2CSV([1004, options]));

        }
        else if (num == 9384610)
        {
            if (isMaster == 0) //markering
                //llMessageLinked(LINK_THIS, 5598321, llList2CSV([id, str, FALSE]), "");
                sendTextBatch(broadcastChannel, llList2CSV([1003, id, str, FALSE]));
            else
                addAgent(id, str, TRUE);
        }
        else if (num == 345149625)
        {
            //Return Translation
            processHTTPResponse(0, str, llCSV2List(id));
        }
        else if (num == 345149626)
        {
            //Return Detection
            processHTTPResponse(1, str, llCSV2List(id));
        }
    }
    timer()
    {
        integer x;
        string  tempString;
        list    newList;
        integer translatorCount = llGetListLength(translators)/2;

        if (isInitialized == FALSE)
        {
            isInitialized = TRUE;
            enabled = TRUE;
            listenID = llListen(0, "", "", "");
            llListen(777, "", NULL_KEY, "");

            llMessageLinked(LINK_THIS, 6877259, (string)enabled, NULL_KEY);
        }

        llMessageLinked(LINK_THIS, 94558323, llList2CSV(agentsInTranslation), "");
        if (isMaster > 0)
        {
            for (x = 0; x < llGetListLength(agentsInTranslation); x += 4)
            {
                tempString = llList2String(llGetObjectDetails(llList2Key(agentsInTranslation, x), [OBJECT_POS]), 0);
                if ((llVecDist(llGetPos(), (vector)tempString) <= 20.0) && (tempString != ""))
                    newList += llList2List(agentsInTranslation, x, x + 3);
            }

            agentsInTranslation = newList;
            if ((llGetUnixTime() - lastHeartBeat) >= 5)
            {
                //Send heartbeat
                sendHeartbeat();
                lastHeartBeat = llGetUnixTime();
            }
        }
        else
        {
            if ((llGetUnixTime() - lastHeartBeat) >= 0 + llGetListLength(agentsInTranslation)*2 + llPow(translatorCount, 1.4) + translatorCount + ((1-llGetRegionTimeDilation()) * 5))
            {
                //Send heartbeat
                sendHeartbeat();
                lastHeartBeat = llGetUnixTime();
            }
        }

        //turn on and off scanner
        if ((autoLanguage) && (isMaster > 0))
        {
            llSensor("", NULL_KEY, AGENT, 20.0, PI);
        }
        //llSetTimerEvent(4 + ((1-llGetRegionTimeDilation()) * 5));
    }

    listen(integer channel, string name, key id, string message)
    {
        integer x;
        string  speakerLanguage;
        string  recepientLanguage;
        integer recepientID;
        integer listPos;
        string  languagePair;
        list    translationCache;
        list    tempList;
        integer ImessageType;
        string  Imessage;
        string  tempString;
        string  tempString2;

        //Multiplexor Code
        if ((channel == broadcastChannel) || (channel == priorityNumber))
        {
            //==========================
            //Process Proxy HTTP Request
            //==========================

            if (channel == priorityNumber)
            {
                if (llStringLength(message) >= 508)
                {
                    if (((integer)message/channel) != 4958654)
                    {
                        sayCachePrivate += [id, message];
                        return;
                    }
                    message = "";
                }
                message = receiveTextBatchPrivate(id, message);
                //Received packet to translate
                llMessageLinked(LINK_ALL_CHILDREN, 6634934, (string)<0.25, 0.05, 0.25>, "");

                tempList = llParseString2List(message, ["~"], []);
                tempString = llList2String(tempList, 0);
                tempList = llDeleteSubList(tempList, 0, 0);

                tempString2 = llDumpList2String(tempList, "|");
                tempList = llCSV2List(tempString);
                listPos = llList2Integer(tempList, 0);
                tempList = llDeleteSubList(tempList, 0, 0);
                checkThrottle(listPos, tempString2, tempList);

                return;
            }

            //=======================
            //Process Global Messages
            //=======================
            if (llStringLength(message) >= 508)
            {
                if (((integer)message/channel) != 4958654)
                {
                    sayCache += [id, message];
                    return;
                }
                message = "";
            }
            message = receiveTextBatch(id, message);

            tempList = llCSV2List(message);

            if (llGetListLength(tempList) >= 2)
            {
                ImessageType = llList2Integer(tempList, 0);
                tempList = llDeleteSubList(tempList, 0, 0);
                Imessage = llList2CSV(tempList);

                llMessageLinked(LINK_ALL_CHILDREN, 6634934, (string)<0.25, 0, 0.25>, "");
                //Process Message Here
                if (ImessageType == 1001)
                {
                    //Incoming Heartbeat
                    if ((integer)Imessage == priorityNumber)
                    {
                        llOwnerSay("Priority Number Conflict!  Resetting Script...");
                        llResetScript(); //Reset if conflicting priority number
                    }
                    listPos = llListFindList(translators, [id]);
                    if (listPos < 0)
                    {
                        translators += [(integer)Imessage, id];
                        if ((isMaster > 0) && (isInitialized))
                        {
                            sendTextBatch((integer)Imessage, llList2CSV([1002, llList2CSV(agentsInTranslation)]));
                            sendTextBatch((integer)Imessage, llList2CSV([1004, options]));
                        }
                    }
                    else
                    {
                        translators = llListReplaceList(translators, [(integer)Imessage], listPos - 1, listPos - 1);
                    }
                }
                else if (ImessageType == 1002)
                {
                    //Incoming agentsInTranslation Master Broadcast
                    if (isMaster == 0)
                    {
                        //llMessageLinked(LINK_THIS, 9458021, Imessage, "");
                        tempList = llCSV2List(Imessage);
                        agentsInTranslation = [];
                        for (x = 0; x < llGetListLength(tempList); x += 4)
                        {
                            agentsInTranslation += [llList2Key(tempList, x), llList2String(tempList, x + 1), llList2Integer(tempList, x + 2), llList2Integer(tempList, x + 3)];
                        }
                    }
                }
                else if (ImessageType == 1003)
                {
                    //Incoming agentsInTranslation dump from Slave
                    tempList = llCSV2List(Imessage);
                    for (x = 0; x < llGetListLength(tempList); x += 4)
                    {
                        addAgent(llList2Key(tempList, x), llList2String(tempList, x + 1), llList2Integer(tempList, x + 2));
                    }
                }
                else if (ImessageType == 1004)
                {
                    //Incoming Preferences
                    options = Imessage;
                    tempList = llCSV2List(options);
                    showTranslation = llList2Integer(tempList, 0);
                    tranObjects = llList2Integer(tempList, 1);
                    autoLanguage = llList2Integer(tempList, 2);

                    llMessageLinked(LINK_THIS, 3342977, Imessage, "");
                }
            }

            return;
        }

        //Translator Engine Code
        if ((llToLower(message) == "translator") && (isMaster > 0))
        {
            llMessageLinked(LINK_THIS, 2540664, message, id);
            return;
        }
        if ((!enabled) && (isMaster == 1)) return;

        if (!tranObjects)
        {
            if (llList2Key(llGetObjectDetails(id, [OBJECT_CREATOR]), 0) != NULL_KEY) return;
        }

        listPos = llListFindList(agentsInTranslation, [id]);
        if (listPos >= 0)
        {
            speakerLanguage = llList2String(agentsInTranslation, listPos + 1);
        }
        else
        {
            speakerLanguage = addNewAgent(id);
        }

        if (speakerLanguage == "xx") return;  //Agent Opt-Out

        llMessageLinked(LINK_ALL_CHILDREN, 6634934, (string)<1, 1, 0>, "");
        //===============================
        //Formulate Translation Requests
        //===============================
        for (x = 0; x < llGetListLength(agentsInTranslation); x += 4)
        {
            //Loop through translation group and do appropriate translations as needed
            recepientID = llList2Integer(agentsInTranslation, x + 3);
            recepientLanguage =  checkLanguage(llList2Key(agentsInTranslation, x + 1));
            if ((speakerLanguage != recepientLanguage) && (recepientLanguage != "") && (speakerLanguage != "") && (recepientLanguage != "xx"))
            {
                languagePair = speakerLanguage + "|" + recepientLanguage;
                listPos = llListFindList(translationCache, [languagePair]);
                if (listPos < 0)
                  translationCache += [languagePair, recepientID];
                else
                  translationCache = llListReplaceList(translationCache, [llList2String(translationCache, listPos + 1) + "@" + (string)recepientID], listPos + 1, listPos + 1);
            }
        }

        //Process Requests
        if (llGetListLength(translationCache) > 0)
        {
            for (x = 0; x < llGetListLength(translationCache); x += 2)
            {
                //====================================
                //Translation
                //====================================
                //Forumulate and Send Translation Request
                languagePair = llList2String(translationCache, x);
                //languagePair = "|" + llList2String(llParseStringKeepNulls(llList2String(translationCache, x), ["|"],[]), 1);
                //languagePair = speakerLanguage + "|" + recepientLanguage;
                //checkThrottle(0, llEscapeURL(message) + "&langpair=" + llEscapeURL(languagePair), [llGetTime(), id , llList2String(translationCache, x + 1), llList2String(translationCache, x)]);
                checkThrottle(0, llEscapeURL(message), [llGetTime(), id , llList2String(translationCache, x + 1), llList2String(translationCache, x)]);
            }
        }
        else
            speakerLanguage = "";

        //====================================
        //Language Detection
        //====================================
        if (llList2Key(llGetObjectDetails(id, [OBJECT_CREATOR]), 0) == NULL_KEY)
        {
            if (((speakerLanguage == "") || (llList2Integer(agentsInTranslation, llListFindList(agentsInTranslation, [id]) + 2) == TRUE)) || (isMaster == 2))
            {
                //Forumulate and Send Language Detect Request
                checkThrottle(1, llEscapeURL(message), [llGetTime(), id]);
            }
        }
    }

    http_response(key request_id, integer status, list metadata, string body)
    {
        string  tempString;

        if (status != 200)
        {
            //llOwnerSay("WWW Error:" + (string)status);
            llMessageLinked(LINK_ALL_CHILDREN, 6634934, (string)<1, 0, 0>, "");
            //llOwnerSay(body);
            return;
        }
        //Process Resonse Code
        tempString = llGetSubString(body, llSubStringIndex(body, "\"code\":"), -1);
//        status = (integer)llGetSubString(tempString, 17, llSubStringIndex(tempString, "}") - 1);
//        status = (integer)llGetSubString(tempString, 8, 10) llSubStringIndex(tempString, ":"), llSubStringIndex(tempString, ",") - 1);
        status = (integer)llGetSubString(tempString, llSubStringIndex(tempString, ":") + 1, llSubStringIndex(tempString, ",") - 1);
        if (status != 200)
        {
            //llOwnerSay("Language Server Returned Error Code: " + (string)status);
            //llOwnerSay(body);
            llMessageLinked(LINK_ALL_CHILDREN, 6634934, (string)<1, 0, 0>, "");
            return;
        }
        llMessageLinked(LINK_ALL_CHILDREN, 6634934, (string)<0, 0, 1>, "");
        llMessageLinked(LINK_THIS, 345149624, body, request_id);
    }
}
