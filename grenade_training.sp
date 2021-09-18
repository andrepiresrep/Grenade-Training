#include <sourcemod>
#include <sdktools>
#include <cstrike>

#define GRENADE_WEAPON_NAME "weapon_hegrenade"
#define FLASHBANG_WEAPON_NAME "weapon_flashbang"
#define FLASHBANG "flashbang"
#define SMOKE_WEAPON_NAME "weapon_smokegrenade"

ConVar g_cWelcomeMessage = null;
ConVar g_cAllowNoclip = null;
int m_hMyWeapons;

public Plugin myinfo =
{
	name = "Grenade training",
	author = "rebL https://steamcommunity.com/id/criticalsoft/",
	description = "Allows getting all CS:S grenades at all times and using noclip",
	version = "1.0",
	url = "http://www.sourcemod.net/"
};

public void OnPluginStart()
{
	// Taken from https://forums.alliedmods.net/showthread.php?t=58176
    	m_hMyWeapons = FindSendPropOffs("CBasePlayer", "m_hMyWeapons");

    	if (m_hMyWeapons == -1)
    	{
        	char error[128];
        	FormatEx(error, sizeof(error), "FATAL ERROR m_hMyWeapons [%d]. Please contact the author.", m_hMyWeapons);
        	SetFailState(error);
    	}

	g_cAllowNoclip = CreateConVar("sm_allow_noclip", "1", "1 if noclip is allowed, false otherwise.");
	g_cWelcomeMessage = CreateConVar("sm_grenade_training_welcome_message", "Type bind i sm_toggle_noclip in the console to use noclip. Type bind o sm_give_nades in the console to receive all grenades. Type rtv in chat to vote to change map. Type nominate in chat to nominate a map.", "The welcome message players receive after connecting. The welcome message must have at max 511 characters");
	RegConsoleCmd("sm_toggle_noclip", ToggleNoclip);
	RegConsoleCmd("sm_give_nades", GiveGrenades);
	AutoExecConfig(true, "grenade_training");
}

// Creates a timer that will run 10 seconds after the client has connected.
// This is used so that we can display a welcome message to the client.
public bool OnClientConnect(int client, char[] rejectmsg, int maxlen)
{
	CreateTimer(10.0, Timer_Advertise, client);
	return true;
}

public Action Timer_Advertise(Handle timer, int client)
{
	if (IsClientInGame(client))
	{
		char welcomeMessage[512];
		GetConVarString(g_cWelcomeMessage, welcomeMessage, sizeof(welcomeMessage));
 		PrintToChat(client, "\x04%s", welcomeMessage);
	}
	else if (IsClientConnected(client))
	{
		CreateTimer(10.0, Timer_Advertise, client);
	}
}

public Action ToggleNoclip(int client, int args)
{
	if (g_cAllowNoclip.IntValue == 1 && IsClientInGame(client) && !IsFakeClient(client) && PlayerIsCtOrT(client) && IsPlayerAlive(client))
	{
		MoveType movetype = GetEntityMoveType(client);

		if (movetype != MOVETYPE_NOCLIP)
		{
			SetEntityMoveType(client, MOVETYPE_NOCLIP);
		}
		else if (movetype != MOVETYPE_WALK)
		{
			SetEntityMoveType(client, MOVETYPE_WALK);
		}
	}

	return Plugin_Handled;
}

// Give the max grenades to the player that he does not have.
// At most 1 hegrenade, 1 flashbang and 1 smokegrenade.
// We only allow the player carrying at most 1 flashbang because we couldn't find a way
// to find out how many flashbangs a player has without resorting to external plugins and we don't want external plugins.
public Action GiveGrenades(int client, int args)
{
	if (IsClientInGame(client) && !IsFakeClient(client) && PlayerIsCtOrT(client) && IsPlayerAlive(client))
	{
		int hegrenadeCount = CheckForPlayerGrenadeExistence(client, GRENADE_WEAPON_NAME);
		int flashbangCount = CheckForPlayerGrenadeExistence(client, FLASHBANG_WEAPON_NAME);
		int smokegrenadeCount = CheckForPlayerGrenadeExistence(client, SMOKE_WEAPON_NAME);

		if (hegrenadeCount != 1)
		{
			GivePlayerItem(client, GRENADE_WEAPON_NAME);
			hegrenadeCount = 1;
		}

		if (flashbangCount != 1)
		{
			GivePlayerItem(client, FLASHBANG_WEAPON_NAME);
			flashbangCount = 1;
		}

		if (smokegrenadeCount != 1)
		{
			GivePlayerItem(client, SMOKE_WEAPON_NAME);
			smokegrenadeCount = 1;
		}
	}

	return Plugin_Handled;
}

// We only allow the player carrying at most 1 flashbang because we couldn't find a way
// to find out how many flashbangs a player has without resorting to external plugins and we don't want external plugins.
public Action CS_OnBuyCommand(int client, const char[] weapon)
{
	if (client > 0 && IsClientInGame(client))
	{
		// Check if the player already has a flashbang.
		// To prevent him from buying another one.
		if (strcmp(weapon, FLASHBANG, false) == 0 && CheckForPlayerGrenadeExistence(client, FLASHBANG_WEAPON_NAME) == 1)
		{
			PrintToChat(client, "\x04%s", "You can only carry 1 flashbang at a time");
			return Plugin_Handled;
		}
	}
	
	return Plugin_Continue;
}

// We only allow the player carrying at most 1 flashbang because we couldn't find a way
// to find out how many flashbangs a player has without resorting to external plugins and we don't want external plugins.
public Action Event_OnItemPickup(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!client || !IsClientInGame(client))
	{
		return Plugin_Continue;
	}

	char itemPickedUp[24];
	GetEventString(event, "item", itemPickedUp, sizeof(itemPickedUp));

	// Prevent the player from picking up a second flashbang.
	if (strcmp(itemPickedUp, FLASHBANG, false) == 0 && CheckForPlayerGrenadeExistence(client, FLASHBANG_WEAPON_NAME) == 1)
	{
		PrintToChat(client, "\x04%s", "You can only carry 1 flashbang at a time");
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

// We only allow the player carrying at most 1 flashbang because we couldn't find a way
// to find out how many flashbangs a player has without resorting to external plugins and we don't want external plugins.
int CheckForPlayerGrenadeExistence(int client, char[] grenadeName)
{
	int grenadeCount = 0;
	for (int i = 0, ent; i < 128; i += 4) // Should increment by 4 as we want to get the start of the next word.
    	{
        	ent = GetEntDataEnt2(client, m_hMyWeapons + i);

        	if (ent > 0)
        	{
			char className[64];
			GetEdictClassname(ent, className, sizeof(className));

            		if (strcmp(className, grenadeName, false) == 0)
			{
				grenadeCount = 1;
				break;
			}
        	}
    	}
	return grenadeCount;
}

bool PlayerIsCtOrT(int client)
{
	return GetClientTeam(client) == CS_TEAM_CT || GetClientTeam(client) == CS_TEAM_T;
}