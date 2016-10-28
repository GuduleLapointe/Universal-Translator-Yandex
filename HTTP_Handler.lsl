//HTTP Handler
// Part of Universal Translator (Yandex)
// Version Yandex-1.0
// ©2016 Gudule Lapointe gudule@speculoos.world
// Based on Universal Translator 1.9.0 (Google) ©2006-2009 Hank Ramos

list requestedTranslations;
list requestedDetections;

debug(string message)
{
    llOwnerSay("/me DEBUG: " + message);
}

default
{
    state_entry()
    {
        llSetTimerEvent(5);
    }

    timer()
    {
        integer x;
        list    newList;
        float timeElapsed;

        for (x = 0; x < llGetListLength(requestedDetections); x += 2)
        {
            timeElapsed = llGetTime() - llList2Float(llCSV2List(llList2String(requestedDetections, x + 1)), 0);
            if (timeElapsed < 60.0)
                newList += llList2List(requestedDetections, x, x + 1);
        }
        requestedDetections = newList;
        newList = [];
        for (x = 0; x < llGetListLength(requestedTranslations); x += 2)
        {
            timeElapsed = llGetTime() - llList2Float(llCSV2List(llList2String(requestedTranslations, x + 1)), 0);
            if (timeElapsed < 60.0)
            {
                newList += llList2List(requestedTranslations, x, x + 1);
            }
        }
        requestedTranslations = newList;
    }

    link_message(integer sender_num, integer num, string str, key id)
    {
        integer listPos;

        if (num == 235365342)
        {
            //debug("got translation " + num
            //    + "\nstr " + str
            //    + "\nid " + id
            //);
            //Translation
            requestedTranslations += [id, str];
        }
        else if (num == 235365343)
        {
            //Detection
//            debug("detection request " + id + " str " + str);
            requestedDetections += [id, str];
        }
        else if (num == 345149624)
        {
            listPos = llListFindList(requestedTranslations, [id]);
            if (listPos >= 0)
            {
                llMessageLinked(LINK_THIS, 345149625, str, llList2String(requestedTranslations, listPos + 1));
                requestedTranslations = llDeleteSubList(requestedTranslations, listPos, listPos + 1);
                return;
            }

            listPos = llListFindList(requestedDetections, [id]);
            if (listPos >= 0)
            {
                llMessageLinked(LINK_THIS, 345149626, str, llList2String(requestedDetections, listPos + 1));
                requestedDetections = llDeleteSubList(requestedDetections, listPos, listPos + 1);
            }
        }
    }
}
