#include "vr_macros.qc"

float DOOR_START_OPEN     = VRUTIL_POWER_OF_TWO(0);
float DOOR_DONT_LINK      = VRUTIL_POWER_OF_TWO(2); // This was 2^2, not sure why not 2^1
float DOOR_GOLD_KEY       = VRUTIL_POWER_OF_TWO(3);
float DOOR_SILVER_KEY     = VRUTIL_POWER_OF_TWO(4);
float DOOR_TOGGLE         = VRUTIL_POWER_OF_TWO(5);
float DOOR_TRIGGER_ON_END = VRUTIL_POWER_OF_TWO(6); // HONEY

/*

Doors are similar to buttons, but can spawn a fat trigger field around them
to open without a touch, and they link together to form simultanious
double/quad doors.

Door.owner is the master door.  If there is only one door, it points to itself.
If multiple doors, all will point to a single one.

Door.enemy chains from the master door through all doors linked in the chain.

*/

/*
=============================================================================

THINK FUNCTIONS

=============================================================================
*/

void() door_blocked =
{
    T_Damage(other, self, self, self.dmg);

// if a door has a negative wait, it would never come back if blocked,
// so let it just squash the object to death real fast
    if(self.wait >= 0)
    {
        if(self.state == STATE_DOWN)
            door_go_up();
        else
            door_go_down();
    }
};


void() door_hit_top =
{
    sound(self, CHAN_VOICE, self.noise1, 1, ATTN_NORM);
    self.state = STATE_TOP;

    // HONEY
    if(self.spawnflags & DOOR_TRIGGER_ON_END)
        SUB_UseTargets();

    if(self.spawnflags & DOOR_TOGGLE)
        return;        // don't come down automatically

    self.think = door_go_down;
    self.nextthink = self.ltime + self.wait;
};

void() door_hit_bottom =
{
    sound(self, CHAN_VOICE, self.noise1, 1, ATTN_NORM);
    self.state = STATE_BOTTOM;
};

void() door_go_down =
{
    float speed2; // HONEY

    sound(self, CHAN_VOICE, self.noise2, 1, ATTN_NORM);
    if(self.max_health)
    {
        self.takedamage = DAMAGE_YES;
        self.health = self.max_health;
    }

    // HONEY
    if(self.cnt) { speed2 = self.speed * self.cnt; }
    else { speed2 = self.speed; }

    self.state = STATE_DOWN;
    SUB_CalcMove(self.pos1, speed2, door_hit_bottom);
};

void() door_go_up =
{
    if(self.state == STATE_UP)
        return;        // allready going up

    if(self.state == STATE_TOP)
    {    // reset top wait time
        self.nextthink = self.ltime + self.wait;
        return;
    }

    sound(self, CHAN_VOICE, self.noise2, 1, ATTN_NORM);
    self.state = STATE_UP;
    SUB_CalcMove (self.pos2, self.speed, door_hit_top);

    if(!(self.spawnflags & DOOR_TRIGGER_ON_END)) { // HONEY
        SUB_UseTargets();
    }
};


/*
=============================================================================

ACTIVATION FUNCTIONS

=============================================================================
*/

void() door_fire =
{
    entity     oself;
    entity    starte;

    if(self.owner != self)
        objerror ("door_fire: self.owner != self");

// play use key sound

    if(self.vr_itemId)
    {
        sound(self, CHAN_ITEM, self.noise4, 1, ATTN_NORM);

        // HONEY
        if(self.lefty)
        {
            self.vr_itemId = 0;
            self.touch = SUB_Null;
            self.goalentity = activator; // Save activator here
            SUB_DoLater(door_fire, self.lefty); // Delay opening
            return;
        }
    }

    // HONEY
    if(self.lefty)
    {
        activator = self.goalentity; //Restore activator here
        self.lefty = 0;
    }


    self.message = string_null;        // no more message
    oself = self;

    if(self.spawnflags & DOOR_TOGGLE)
    {
        if(self.state == STATE_UP || self.state == STATE_TOP)
        {
            starte = self;
            do
            {
                door_go_down();
                self = self.enemy;
            } while((self != starte) && (self != world));
            self = oself;
            return;
        }
    }

// trigger all paired doors
    starte = self;
    do
    {
        door_go_up();
        self = self.enemy;
    } while((self != starte) && (self != world));
    self = oself;
};


void() door_use =
{
    entity oself;

    self.message = "";            // door message are for touch only
    self.owner.message = "";
    self.enemy.message = "";
    oself = self;
    self = self.owner;
    door_fire();
    self = oself;
};


void() door_trigger_touch =
{
    if(other.health <= 0)
        return;

    if(time < self.attack_finished)
        return;

    self.attack_finished = time + 1;

    activator = other;

    self = self.owner;
    door_use();
};


void() door_killed =
{
    entity oself;

    oself = self;
    self = self.owner;
    self.health = self.max_health;
    self.takedamage = DAMAGE_NO;    // wil be reset upon return
    door_use();
    self = oself;
};


/*
================
door_touch

Prints messages and opens key doors
================
*/
void() door_touch =
{
    if(other.classname != "player")
        return;

    if(self.owner.attack_finished > time)
        return;

    self.owner.attack_finished = time + 2;

    if(self.owner.message != "")
    {
        centerprint(other, self.owner.message);
        sound(other, CHAN_VOICE, "misc/talk.wav", 1, ATTN_NORM);
    }

// key door stuff
    if(!self.vr_itemId)
        return;

// FIXME: blink key on player's status bar
    if(!VR_ItemUtil_EntHasItem(other, self.vr_itemId))
    {
        if(self.owner.vr_itemId == IID_KEY1)
        {
            if(world.worldtype == 2)
            {
                centerprint(other, "You need the silver keycard");
                sound(self, CHAN_VOICE, self.noise3, 1, ATTN_NORM);
            }
            else if(world.worldtype == 1)
            {
                centerprint(other, "You need the silver runekey");
                sound(self, CHAN_VOICE, self.noise3, 1, ATTN_NORM);
            }
            else if(world.worldtype == 0)
            {
                centerprint(other, "You need the silver key");
                sound(self, CHAN_VOICE, self.noise3, 1, ATTN_NORM);
            }
        }
        else
        {
            if(world.worldtype == 2)
            {
                centerprint(other, "You need the gold keycard");
                sound(self, CHAN_VOICE, self.noise3, 1, ATTN_NORM);
            }
            else if(world.worldtype == 1)
            {
                centerprint(other, "You need the gold runekey");
                sound(self, CHAN_VOICE, self.noise3, 1, ATTN_NORM);
            }
            else if(world.worldtype == 0)
            {
                centerprint(other, "You need the gold key");
                sound(self, CHAN_VOICE, self.noise3, 1, ATTN_NORM);
            }
        }
        return;
    }

    VR_ItemUtil_EntDelItem(other, self.vr_itemId);
    self.touch = SUB_Null;

    if(self.enemy)
    {
        self.enemy.touch = SUB_Null;    // get paired door
    }

    // HONEY
    activator = other;

    door_use();
};

/*
=============================================================================

SPAWNING FUNCTIONS

=============================================================================
*/


entity(vector fmins, vector fmaxs) spawn_field =
{
    entity    trigger;
    vector    t1, t2;

    trigger = spawn();
    trigger.movetype = MOVETYPE_NONE;
    trigger.solid = SOLID_TRIGGER;
    trigger.owner = self; //Always the master door...

    // HONEY
    if(self.cnt)
    {
        trigger.touch = door_temp_trigger_touch;
    }
    else
    {
        trigger.touch = door_trigger_touch;
    }

    t1 = fmins;
    t2 = fmaxs;
    setsize(trigger, t1 - '60 60 8', t2 + '60 60 8');
    return (trigger);
};


float (entity e1, entity e2) EntitiesTouching =
{
    if(e1.mins_x > e2.maxs_x)
        return FALSE;
    if(e1.mins_y > e2.maxs_y)
        return FALSE;
    if(e1.mins_z > e2.maxs_z)
        return FALSE;
    if(e1.maxs_x < e2.mins_x)
        return FALSE;
    if(e1.maxs_y < e2.mins_y)
        return FALSE;
    if(e1.maxs_z < e2.mins_z)
        return FALSE;
    return TRUE;
};


/*
=============
LinkDoors

cg: self.owner always is the master door and self.enemy is always the next door in the chain

=============
*/
void() LinkDoors =
{
    entity    t, starte;
    vector    cmins, cmaxs;

    if(self.enemy)
        return;        // already linked by another door

    if(self.spawnflags & DOOR_DONT_LINK)
    {
        self.owner = self.enemy = self;
        return;        // don't want to link this door
    }

    cmins = self.mins;
    cmaxs = self.maxs;

    starte = self;
    t = self;

    do
    {
        self.owner = starte;            // master door

        if(self.health)
            starte.health = self.health;

        // HONEY
        if(self.cnt)
            starte.cnt = self.cnt;

        // HONEY
        if(self.lefty)
            starte.lefty = self.lefty;

        if(self.targetname != NULLSTR)
            starte.targetname = self.targetname;

        if(self.message != "")
            starte.message = self.message;

        t = find(t, classname, self.classname);
        if(!t)
        {
            self.enemy = starte;        // make the chain a loop

        // shootable, fired, or key doors just needed the owner/enemy links,
        // they don't spawn a field

            self = self.owner;

            if(self.health)
                return;

            if(self.targetname != "" && /* HONEY */ !self.cnt)
                return;

            if(self.vr_itemId)
                return;

            self.owner.trigger_field = spawn_field(cmins, cmaxs);

            return;
        }

        if(EntitiesTouching(self,t))
        {
            if(t.enemy)
                objerror ("cross connected doors");

            self.enemy = t;
            self = t;

            if(t.mins_x < cmins_x)
                cmins_x = t.mins_x;
            if(t.mins_y < cmins_y)
                cmins_y = t.mins_y;
            if(t.mins_z < cmins_z)
                cmins_z = t.mins_z;
            if(t.maxs_x > cmaxs_x)
                cmaxs_x = t.maxs_x;
            if(t.maxs_y > cmaxs_y)
                cmaxs_y = t.maxs_y;
            if(t.maxs_z > cmaxs_z)
                cmaxs_z = t.maxs_z;
        }
    } while(1);

};


/*QUAKED func_door (0 .5 .8) ? START_OPEN x DOOR_DONT_LINK GOLD_KEY SILVER_KEY TOGGLE
if two doors touch, they are assumed to be connected and operate as a unit.

TOGGLE causes the door to wait in both the start and end states for a trigger event.

START_OPEN causes the door to move to its destination when spawned, and operate in reverse.  It is used to temporarily or permanently close off an area when triggered (not usefull for touch or takedamage doors).

Key doors are allways wait -1.

"message"    is printed when the door is touched if it is a trigger door and it hasn't been fired yet
"angle"        determines the opening direction
"targetname" if set, no touch field will be spawned and a remote button or trigger field activates the door.
"health"    if set, door must be shot open
"speed"        movement speed (100 default)
"wait"        wait before returning (3 default, -1 = never return)
"lip"        lip remaining at end of move (8 default)
"dmg"        damage to inflict when blocked (2 default)
"sounds"
0)    no sound
1)    stone
2)    base
3)    stone chain
4)    screechy metal
*/

void() func_door =
{
    if(world.worldtype == 0)
    {
        precache_sound("doors/medtry.wav");
        precache_sound("doors/meduse.wav");
        self.noise3 = "doors/medtry.wav";
        self.noise4 = "doors/meduse.wav";
    }
    else if(world.worldtype == 1)
    {
        precache_sound("doors/runetry.wav");
        precache_sound("doors/runeuse.wav");
        self.noise3 = "doors/runetry.wav";
        self.noise4 = "doors/runeuse.wav";
    }
    else if(world.worldtype == 2)
    {
        precache_sound("doors/basetry.wav");
        precache_sound("doors/baseuse.wav");
        self.noise3 = "doors/basetry.wav";
        self.noise4 = "doors/baseuse.wav";
    }
    else
    {
        dprint("no worldtype set!\n");
    }

    if(self.sounds == 0)
    {
        precache_sound("misc/null.wav");
        precache_sound("misc/null.wav");
        self.noise1 = "misc/null.wav";
        self.noise2 = "misc/null.wav";
    }
    else if(self.sounds == 1)
    {
        precache_sound("doors/drclos4.wav");
        precache_sound("doors/doormv1.wav");
        self.noise1 = "doors/drclos4.wav";
        self.noise2 = "doors/doormv1.wav";
    }
    else if(self.sounds == 2)
    {
        precache_sound("doors/hydro1.wav");
        precache_sound("doors/hydro2.wav");
        self.noise2 = "doors/hydro1.wav";
        self.noise1 = "doors/hydro2.wav";
    }
    else if(self.sounds == 3)
    {
        precache_sound("doors/stndr1.wav");
        precache_sound("doors/stndr2.wav");
        self.noise2 = "doors/stndr1.wav";
        self.noise1 = "doors/stndr2.wav";
    }
    else if(self.sounds == 4)
    {
        precache_sound("doors/ddoor1.wav");
        precache_sound("doors/ddoor2.wav");
        self.noise1 = "doors/ddoor2.wav";
        self.noise2 = "doors/ddoor1.wav";
    }

    if(!self.movedir)
        SetMovedir();

    self.max_health = self.health;
    self.solid = SOLID_BSP;
    self.movetype = MOVETYPE_PUSH;
    setorigin(self, self.origin);
    setmodel(self, self.model);
    self.classname = "door";

    self.blocked = door_blocked;
    self.use = door_use;

    if(self.spawnflags & DOOR_SILVER_KEY)
    {
        self.vr_itemId = IID_KEY1;
    }

    if(self.spawnflags & DOOR_GOLD_KEY)
    {
        self.vr_itemId = IID_KEY2;
    }

    if(!self.speed) { self.speed = 100; }
    if(!self.wait)  { self.wait = 3; }
    if(!self.lip)   { self.lip = 8; }
    if(!self.dmg)   { self.dmg = 2; }

    // HONEY
    if(VR_GameUtil_EnableHoneyExtensions() && !self.lefty)
    {
        self.lefty = 1;
    }

    self.pos1 = self.origin;

    // PGM fix for cameron's door problem - 02/19/97
    vector tempVect;
    tempVect = self.movedir;

    if(tempVect_x < 0)
    {
        tempVect_x = 0 - tempVect_x;
    }

    if(tempVect_y < 0)
    {
        tempVect_y = 0 - tempVect_y;
    }

    if(!self.pos2) // HONEY
    {
        self.pos2 = self.pos1 + self.movedir*(fabs(tempVect*self.size) - self.lip);
    }
    else
    {
        self.pos2 = self.pos1 + self.pos2;
    }

    // DOOR_START_OPEN is to allow an entity to be lighted in the closed position
    // but spawn in the open position
    if(self.spawnflags & DOOR_START_OPEN)
    {
        setorigin(self, self.pos2);
        self.pos2 = self.pos1;
        self.pos1 = self.origin;
    }

    self.state = STATE_BOTTOM;

    if(self.health)
    {
        self.takedamage = DAMAGE_YES;
        self.th_die = door_killed;
    }

    if(self.vr_itemId)
    {
        self.wait = -1;
    }

    self.touch = door_touch;

// LinkDoors can't be done until all of the doors have been spawned, so
// the sizes can be detected properly.
    self.think = LinkDoors;
    self.nextthink = self.ltime + 0.1;
};

/*
=============================================================================

SECRET DOORS

=============================================================================
*/

void() fd_secret_move1;
void() fd_secret_move2;
void() fd_secret_move3;
void() fd_secret_move4;
void() fd_secret_move5;
void() fd_secret_move6;
void() fd_secret_done;

float SECRET_OPEN_ONCE = 1;        // stays open
float SECRET_1ST_LEFT = 2;        // 1st move is left of arrow
float SECRET_1ST_DOWN = 4;        // 1st move is down from arrow
float SECRET_NO_SHOOT = 8;        // only opened by trigger
float SECRET_YES_SHOOT = 16;    // shootable even if targeted


void () fd_secret_use =
{
    float temp;

    self.health = 10000;

    // exit if still moving around...
    if(self.origin != self.oldorigin)
        return;

    self.message = string_null;        // no more message

    SUB_UseTargets();                // fire all targets / killtargets

    if(!(self.spawnflags & SECRET_NO_SHOOT))
    {
        self.th_pain = SUB_NullPain;
        self.takedamage = DAMAGE_NO;
    }
    self.velocity = '0 0 0';

    // Make a sound, wait a little...

    sound(self, CHAN_VOICE, self.noise1, 1, ATTN_NORM);
    self.nextthink = self.ltime + 0.1;

    temp = 1 - (self.spawnflags & SECRET_1ST_LEFT);    // 1 or -1
    makevectors(self.mangle);

    if(!self.t_width)
    {
        if(self.spawnflags & SECRET_1ST_DOWN)
            self. t_width = fabs(v_up * self.size);
        else
            self. t_width = fabs(v_right * self.size);
    }

    if(!self.t_length)
        self. t_length = fabs(v_forward * self.size);

    if(!(self.dest1_x|self.dest1_y|self.dest1_z)) // HONEY
    {
        if(self.spawnflags & SECRET_1ST_DOWN)
            self.dest1 = self.origin - v_up * self.t_width;
        else
            self.dest1 = self.origin + v_right * (self.t_width * temp);
    }

    if(!(self.dest2_x|self.dest2_y|self.dest2_z)) // HONEY
    {
        self.dest2 = self.dest1 + v_forward * self.t_length;
    }

    SUB_CalcMove(self.dest1, self.speed, fd_secret_move1);
    sound(self, CHAN_VOICE, self.noise2, 1, ATTN_NORM);
};

void (entity attacker, float damage) fd_secret_use_pain =
{
    fd_secret_use();
}

// Wait after first movement...
void () fd_secret_move1 =
{
    self.nextthink = self.ltime + 1.0;
    self.think = fd_secret_move2;
    sound(self, CHAN_VOICE, self.noise3, 1, ATTN_NORM);
};

// Start moving sideways w/sound...
void () fd_secret_move2 =
{
    sound(self, CHAN_VOICE, self.noise2, 1, ATTN_NORM);
    SUB_CalcMove(self.dest2, self.speed, fd_secret_move3);
};

// Wait here until time to go back...
void () fd_secret_move3 =
{
    sound(self, CHAN_VOICE, self.noise3, 1, ATTN_NORM);
    if(!(self.spawnflags & SECRET_OPEN_ONCE))
    {
        self.nextthink = self.ltime + self.wait;
        self.think = fd_secret_move4;
    }
};

// Move backward...
void () fd_secret_move4 =
{
    sound(self, CHAN_VOICE, self.noise2, 1, ATTN_NORM);
    SUB_CalcMove(self.dest1, self.speed, fd_secret_move5);
};

// Wait 1 second...
void () fd_secret_move5 =
{
    self.nextthink = self.ltime + 1.0;
    self.think = fd_secret_move6;
    sound(self, CHAN_VOICE, self.noise3, 1, ATTN_NORM);
};

void () fd_secret_move6 =
{
    sound(self, CHAN_VOICE, self.noise2, 1, ATTN_NORM);
    SUB_CalcMove(self.oldorigin, self.speed, fd_secret_done);
};

void () fd_secret_done =
{
    if(!self.targetname || self.spawnflags&SECRET_YES_SHOOT)
    {
        self.health = 10000;
        self.takedamage = DAMAGE_YES;
        self.th_pain = fd_secret_use_pain;
    }
    sound(self, CHAN_VOICE, self.noise3, 1, ATTN_NORM);
};

void () secret_blocked =
{
    if(time < self.attack_finished)
        return;
    self.attack_finished = time + 0.5;
    T_Damage(other, self, self, self.dmg);
};

/*
================
secret_touch

Prints messages
================
*/
void() secret_touch =
{
    if(other.classname != "player")
        return;
    if(self.attack_finished > time)
        return;

    self.attack_finished = time + 2;

    if(self.message != NULLSTR)
    {
        centerprint(other, self.message);
        sound(other, CHAN_BODY, "misc/talk.wav", 1, ATTN_NORM);
    }
};


/*QUAKED func_door_secret (0 .5 .8) ? open_once 1st_left 1st_down no_shoot always_shoot
Basic secret door. Slides back, then to the side. Angle determines direction.
wait  = # of seconds before coming back
1st_left = 1st move is left of arrow
1st_down = 1st move is down from arrow
always_shoot = even if targeted, keep shootable
t_width = override WIDTH to move back (or height if going down)
t_length = override LENGTH to move sideways
"dmg"        damage to inflict when blocked (2 default)

If a secret door has a targetname, it will only be opened by it's botton or trigger, not by damage.
"sounds"
1) medieval
2) metal
3) base
*/

void () func_door_secret =
{
    if(self.sounds == 0)
        self.sounds = 3;
    if(self.sounds == 1)
    {
        precache_sound("doors/latch2.wav");
        precache_sound("doors/winch2.wav");
        precache_sound("doors/drclos4.wav");
        self.noise1 = "doors/latch2.wav";
        self.noise2 = "doors/winch2.wav";
        self.noise3 = "doors/drclos4.wav";
    }
    if(self.sounds == 2)
    {
        precache_sound("doors/airdoor1.wav");
        precache_sound("doors/airdoor2.wav");
        self.noise2 = "doors/airdoor1.wav";
        self.noise1 = "doors/airdoor2.wav";
        self.noise3 = "doors/airdoor2.wav";
    }
    if(self.sounds == 3)
    {
        precache_sound("doors/basesec1.wav");
        precache_sound("doors/basesec2.wav");
        self.noise2 = "doors/basesec1.wav";
        self.noise1 = "doors/basesec2.wav";
        self.noise3 = "doors/basesec2.wav";
    }

    if(!self.dmg)
        self.dmg = 2;

    // Magic formula...
    self.mangle = self.angles;
    self.angles = '0 0 0';
    self.solid = SOLID_BSP;
    self.movetype = MOVETYPE_PUSH;
    self.classname = "door";
    setmodel(self, self.model);
    setorigin(self, self.origin);

    // HONEY
    if(self.dest2_x|self.dest2_y|self.dest2_z)
        self.dest2 = self.origin + self.dest2 + self.dest1;

    // HONEY
    if(self.dest1_x|self.dest1_y|self.dest1_z)
        self.dest1 = self.origin + self.dest1;

    self.touch = secret_touch;
    self.blocked = secret_blocked;

    if(!self.speed) // HONEY
        self.speed = 50;

    self.use = fd_secret_use;
    if(!self.targetname || self.spawnflags&SECRET_YES_SHOOT)
    {
        self.health = 10000;
        self.takedamage = DAMAGE_YES;
        self.th_pain = fd_secret_use_pain;
        self.th_die = fd_secret_use;
    }
    self.oldorigin = self.origin;
    if(!self.wait)
        self.wait = 5;        // 5 seconds before closing
};
