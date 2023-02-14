
--blacklist all actors with the following record id
--use lowercase letters
--to check the actor record id ingame, open console, select the actor and the id should be displayed on top of the console window
--if you edited this file while ingame, type "reloadlua" in the console to refresh

--to blacklist object instances(aka reference), see the script setting in options for instructions.
--these entries cannot be modified during gameplay
local bl =
{
    ["vivec_god"] = true,
    ["yagrum bagarn"] = true,
    --["add_your_own_actor_id_here_to_blacklist_it"] = true, 
}



return bl