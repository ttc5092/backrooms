import processing.sound.*; //sound library needed for audio
/*
SAVEFILE FORMAT:
i  Data
0  Window width
1  Window height
2  Framerate
3  Rendering engine
4  Map size X
5  Map size Y
6  Wall generator type
7  Wall coordinates
8  Exit coordinates
9  Developer mode boolean
10 Game difficulty
11 Year modifier (for aesthetic reasons, no gameplay function)
12 Last score (stored internally in file, displayed at end)
13 Last level
14 Player health
15 Old render distance (for map loading)
16 Player X
17 Player Y
18 Player angle 
19 Audio master volume

The game will load the most recent save file from the data folder.
THE GAME HAS 1735 LINES OF CODE!

Game Over Flag variable
0 - Game running
1 - Game over (dead)
2 - Game ending (cutscene)
3 - Game ending (text screen)
4 - Game ending (credits)
-1 - Title screen
-2 - Options
-3 - Help

Difficulty levels
<1 - Setting difficulty to this value through save editing may cause bugs!
1 - Easy: Entities move slower, more exits
2 - Medium: Default setting
3 - Hard: Entities move faster and deal more damage on attack, less exits
4 - Very hard "You're screwed" - Entities run at same speed as player running straight
>4 - Setting difficulty to this value through save editing makes entities impossible to outrun
*/
SoundFile load,click,alarm,step1,step2,step3,scream,hurt,roar,title,select,birds,teleport; //load sound files
Sound master = new Sound(this); //master volume
WhiteNoise noise; //load noise and triangle oscillators (TV static and AC hum sounds)
TriOsc hum,hum2;
int rayCount = 32; //render distance from settings
int oldRayCount = 32; //render distance from file, used for map loading
float[] ray,ray_e,ray_d; //raycast distance variables
int screenW=640; //screen width from settings
int screenH=480; //screen height from settings
int frm = 60; //frame rate
int mapX = 8192; //walls along north axis of map
int mapY = 8192; //walls along east axis of map
int health = 100; //player health value
int oldStep = 0; //used for step sounds
float vol = 1; //master volume
boolean dev = false; //developer mode flag (cheat code)
int yearMod = int(random(year()-1999,year()-1989)); //year value for time display
String exits,wallArray; //used for loading walls and exits from save file
int diff = 2; //game difficulty level
int score,level,renderer=0; //variables loaded from save file
float px,py,pa,ex,ey,ea,entSpeed; //movement variables

void settings(){
  //load graphics settings from save file, initialize window
  String[] saveFile = loadStrings("savefile.txt");
  screenW = int(saveFile[0]);
  screenH = int(saveFile[1]); //screen size constraints
  if(saveFile[4].length()>0&&saveFile[5].length()>0) {
    mapX = int(saveFile[4]);
    mapY = int(saveFile[5]); //map size constraints
  }
  if(saveFile[2].length()>0) {
    frm = int(saveFile[2]); //maximum framerate
  }
  if(int(saveFile[3])==3) { //fullscreen, default render
    fullScreen();
    screenW = displayWidth;
    renderer = 3;
  }else if(int(saveFile[3])==2) { //fullscreen, P2D/OpenGL rendering
    fullScreen(P2D,SPAN);
    screenW = displayWidth;
    renderer = 2;
  }else if(int(saveFile[3])==1) { //windowed, P2D/OpenGL rendering
    size(int(saveFile[0]),int(saveFile[1]),P2D);
    renderer = 1;
  }else{
    size(int(saveFile[0]),int(saveFile[1])); //default window rendering
    renderer = 0;
  }
  ray = new float[screenW+1]; //initialize raycasting variables
  ray_e = new float[screenW+1];
  ray_d = new float[screenW+1];
  //load parameters related to settings only
  if(saveFile[6].length()>0) rayCount = int(saveFile[6]);
  if(saveFile[10].length()>0) diff = int(saveFile[10]);
  if(saveFile[15].length()>0) oldRayCount = int(saveFile[15]);
  if(saveFile[19].length()>0) vol = float(saveFile[19]);
  //Set master volume
  if(vol>=0&&vol<=1) master.volume(vol);
  smooth();
}

void loadSettings() { //load settings (for options menu) from save file
  String[] saveFile = loadStrings("savefile.txt");
  if(saveFile[0].length()>0) screenW = int(saveFile[0]);
  if(saveFile[1].length()>0) screenH = int(saveFile[1]);
  if(saveFile[2].length()>0) frm = int(saveFile[2]);
  if(saveFile[3].length()>0) renderer = int(saveFile[3]);
  if(saveFile[4].length()>0) mapX = int(saveFile[4]);
  if(saveFile[5].length()>0) mapY = int(saveFile[5]);
  if(saveFile[6].length()>0) rayCount = int(saveFile[6]);
  if(saveFile[10].length()>0) diff = int(saveFile[10]);
  if(saveFile[15].length()>0) oldRayCount = int(saveFile[15]);
  if(saveFile[19].length()>0) vol = float(saveFile[19]);
  //Apply volume
  if(vol>=0&&vol<=1) master.volume(vol);
  //Screen width/height, framerate, and renderer settings are applied only if the game is restarted
}

void loadSave(String[] saveFile) { //load game data from save file
  wall = new int[mapX+1][mapY+1]; //initialize map
  wallArray = saveFile[7]; //validated later when generating walls
  exits = saveFile[8];// door locations
  if(saveFile[4].length()>0) mapX = int(saveFile[4]);
  if(saveFile[5].length()>0) mapY = int(saveFile[5]);
  if(saveFile[9].length()>0) dev = boolean(int(saveFile[9]));
  if(saveFile[11].length()>0) yearMod = int(saveFile[11]);
  if(saveFile[12].length()>0) score = int(saveFile[12]);
  if(saveFile[13].length()>0) level = int(saveFile[13]);
  if(saveFile[14].length()>0) health = int(saveFile[14]);
  if(saveFile[15].length()>0) oldRayCount = int(saveFile[15]);
  if(saveFile[16].length()>0) px = float(saveFile[16]);
  if(saveFile[17].length()>0) py = float(saveFile[17]);
  if(saveFile[18].length()>0) pa = float(saveFile[18]);
}

boolean[] keys = new boolean[6]; //flag variables for keys
final int up = 0; //constants used to reference keys more easily
final int down = 1;
final int left = 2;
final int right = 3;
final int space = 4;
final int com = 5; //menu key
int jumpScareState = 0; //jump scare flag
int[][] wall = new int[mapX+1][mapY+1]; //map layout

/*
MAP LAYOUT ARRAY
0 = empty space
1 = wall (has collision)
2 = light (removed due to issues)
3 = hole in ground (removed due to issues)
4 = portal (teleport to next level)
*/

float xa,ya,oldxa,oldya; //raycasting utility variables: scan X/Y positions
float xc,yc,rd,r; //X and Y increment constant, ray distance, ray angle
int rn,dx,dy; //ray number, door/portal X and Y
int cmdTimer = 0; //command/menu timer
int pSpeed = 5; //player speed
int lightCol = int(random(0,100)); //lighting colour
float rayRes = 1; //entity raycasting resolution
int id = 1; //entity image ID
int game_over = 0; //game over flag
String dir = "NORTH"; //player facing direction
String comm = ""; //command utility variables
String cmd = "";
int dsp = 0; //display mode flag (for debugging purposes)
int immune = 0; //immunity flag (allows player to be immune to entity attacks during debugging)
int em = 1; //entity movement permission, 1 is allow, 0 is disable

void setup(){
  frameRate(frm); //set framerate and background
  background(50,0,255);
  textFont(createFont("vcr_font.ttf", 32));
  load = new SoundFile(this,"load.wav"); //initialize sound files
  scream = new SoundFile(this,"scream.mp3");
  if(int(random(0,2))==0) title = new SoundFile(this,"horror.mp3");
  else title = new SoundFile(this,"horror2.mp3");
  teleport = new SoundFile(this,"teleport.mp3");
  click = new SoundFile(this,"shutter.wav");
  birds = new SoundFile(this,"outdoors.wav");
  select = new SoundFile(this,"select.wav");
  hurt = new SoundFile(this,"hurt.wav");
  roar = new SoundFile(this,"roar.wav");
  noise = new WhiteNoise(this);
  noise.amp(0.5);
  hum = new TriOsc(this);
  hum2 = new TriOsc(this);
  hum.amp(1);
  hum2.amp(1);
  title.amp(1);
  alarm = new SoundFile(this,"alarm.wav");
  game_over = -1; //corresponds to main title screen
  teleport.amp(0.5);
  hurt.amp(0.5);
  roar.amp(0.5);
  title.loop(); //title ambient music
}

void titleScreen() {
  loadSettings(); //load settings from file
  background(25,0,150);
  textSize(48);
  fill(240);
  text("SURVIVE THE",width/2-250,height/3-100); //draw game logo
  textFont(createFont("Unispace Bold.ttf", 128));
  textSize(128);
  fill(200,150,0);
  text("COMPLEX",width/2-240,height/3);
  fill(255,200,0);
  text("COMPLEX",width/2-250,height/3);
  textFont(createFont("vcr_font.ttf", 32));
  //draw interactive buttons
  textSize(32);
  checkButtons(width/2-100,height/2);
  text("NEW GAME",width/2-100,height/2);
  checkButtons(width/2-100,height/2+50);
  text("CONTINUE",width/2-100,height/2+50);
  checkButtons(width/2-100,height/2+100);
  text("OPTIONS",width/2-100,height/2+100);
  checkButtons(width/2-100,height/2+150);
  text("HELP",width/2-100,height/2+150);
  checkButtons(width/2-100,height/2+200);
  text("QUIT GAME",width/2-100,height/2+200);
  textSize(20);
  fill(240);
  text("Developed by Alexander Maji",width/2-175,height-10);
}

void ending() { //ending cutscene
 jumpScareState = -1; //prevent entity jumpscares
 game_over=2;
 load.stop();
 //navigate player around map until a wall is hit
 if(wall[floor((px+cos(pa)*pSpeed)/64)][floor((py+sin(pa)*pSpeed)/64)]!=1) {
   keys[up]=true; //moves player forward only
   keys[left]=false;
   keys[right]=false;
 }else{
   keys[up]=true;
   if(int(random(0,2))==0) { //extra code (I was planning to give the player pathfnding during the cutscene, it didn't work)
     pa-=HALF_PI;
   }
   else {
     pa+=HALF_PI; //prevents player from facing wall when the game autosaves later on
   }
   delay(100);
   game_over = 3; //go to ending text screen
 }
}

void options() { //settings menu
  background(25,0,150);
  fill(255,220,0);
  textSize(48);
  text("Options",width/2-250,height/9);
  fill(240);
  textSize(16);
  text("Restart game to apply graphics settings",width/2-200,height-5);
  textSize(25);
  //draw interactive buttons for each settings parameter (- and + buttons change numerical values)
  text("Map size",width/2-250,height/2-160);
  text(mapX+" x "+mapY,width/2,height/2-160);
  if(smallBtn(width/2-50,height/2-160)&&mapX>256) mapX-=1;
  text("-",width/2-50,height/2-160);//X
  if(smallBtn(width/2-25,height/2-160)&&mapX<8192) mapX+=1;
  text("+",width/2-25,height/2-160);
  if(smallBtn(width/2+175,height/2-160)&&mapY>256) mapY-=1;
  text("-",width/2+175,height/2-160);//Y
  if(smallBtn(width/2+200,height/2-160)&&mapY<8192) mapY+=1;
  text("+",width/2+200,height/2-160);
  fill(240);
  text("Resolution",width/2-250,height/2-128);
  text(screenW+" x "+screenH,width/2,height/2-128);
  if(smallBtn(width/2-50,height/2-128)&&screenW>640) screenW-=1;
  text("-",width/2-50,height/2-128);//X
  if(smallBtn(width/2-25,height/2-128)&&screenW<3840) screenW+=1;
  text("+",width/2-25,height/2-128);
  if(smallBtn(width/2+175,height/2-128)&&screenH>480) screenH-=1;
  text("-",width/2+175,height/2-128);//Y
  if(smallBtn(width/2+200,height/2-128)&&screenH<2160) screenH+=1;
  text("+",width/2+200,height/2-128);
  fill(240);
  text("Frame rate",width/2-250,height/2-96);
  text(frm,width/2+100,height/2-96);
  if(smallBtn(width/2+75,height/2-96)&&frm>20) frm-=1;
  text("-",width/2+75,height/2-96);
  if(smallBtn(width/2+150,height/2-96)&&frm<240) frm+=1;
  text("+",width/2+150,height/2-96);
  fill(240);
  stroke(240);
  text("Display",width/2-250,height/2-64);
  switch(renderer) {
    case 1:
      rect(width/2-10,height/2-64,30,1); //underline selected option
      break;
    case 2:
      rect(width/2+160,height/2-64,150,1);
      break;
    case 3:
      rect(width/2+40,height/2-64,105,1);
      break;
    default:
      rect(width/2-100,height/2-64,70,1);
      break;
  }
  textSize(18);
  if(medBtn(width/2-100,height/2-68)) renderer=0;
  text("Default",width/2-100,height/2-68);
  if(smallBtn(width/2-10,height/2-68)) renderer=1;
  text("P2D",width/2-10,height/2-68);
  if(medBtn(width/2+40,height/2-68)) renderer=3;
  text("Fullscreen",width/2+40,height/2-68);
  if(medBtn(width/2+160,height/2-68)) renderer=2;
  text("Fullscreen+P2D",width/2+160,height/2-68);
  textSize(25);
  fill(240);
  text("Render distance",width/2-250,height/2-32);
  text(rayCount,width/2+100,height/2-32);
  if(smallBtn(width/2+75,height/2-32)&&rayCount>16) rayCount-=1;
  text("-",width/2+75,height/2-32);
  if(smallBtn(width/2+150,height/2-32)&&rayCount<256) rayCount+=1;
  text("+",width/2+150,height/2-32);
  fill(240);
  text("Master volume",width/2-250,height/2);
  text(floor(vol*100)+"%",width/2+100,height/2);
  if(smallBtn(width/2+75,height/2)&&vol>0.01) vol-=0.01;
  text("-",width/2+75,height/2);
  if(smallBtn(width/2+175,height/2)&&vol<1) vol+=0.01;
  text("+",width/2+175,height/2);
  fill(240);
  text(">",width/2-225,height/2+75+(25*diff)); //display arrow next to selected difficulty
  text("Difficulty",width/2-250,height/2+64);
  if(checkBtn(width/2-200,height/2+100)) diff=1;
  text("Easy",width/2-200,height/2+100);
  if(checkBtn(width/2-200,height/2+125)) diff=2;
  text("Medium",width/2-200,height/2+125);
  if(checkBtn(width/2-200,height/2+150)) diff=3;
  text("Pro",width/2-200,height/2+150);
  if(checkBtn(width/2-200,height/2+175)) diff=4;
  text("You're screwed",width/2-200,height/2+175);
  if(checkBtn(floor(width/4-50),height-25)) game_over = -1;
  text("Cancel",width/4-50,height-25);
  if(checkBtn(floor(width/2-25),height-25)) resetSettings();
  text("Reset",width/2-25,height-25);
  if(checkBtn(floor(width/1.5+25),height-25)) saveSettings();
  text("Save",width/1.5+25,height-25);
}

void resetSettings() { //reset setting parameters to defaults
 mapX = 2048;
 mapY = 2048;
 frm = 60;
 screenW = 640;
 screenH = 480;
 renderer = 0;
 rayCount = 32;
 diff = 2;
 vol = 1;
 text("Reset to defaults.",width/2-25,40); 
}

void help() { //display game controls
  background(25,0,150);
  fill(255,220,0);
  textSize(48);
  text("Controls",width/2-250,height/7);
  fill(240);
  textSize(32);
  text("W / up arrow : Move forward",width/2-250,height/2-128);
  text("A / left arrow : Turn left",width/2-250,height/2-96);
  text("S / right arrow : Turn right",width/2-250,height/2-64);
  text("D / down arrow : Move backward",width/2-250,height/2-32);
  text("SPACE : View position",width/2-250,height/2);
  text("SHIFT : Run",width/2-250,height/2+32);
  text("CTRL : Sneak",width/2-250,height/2+64);
  text("`~ : Take screenshot",width/2-250,height/2+96);
  text("/ : Command Menu",width/2-250,height/2+128);
  textSize(25);
  if(checkBtn(floor(width/4-50),height-25)) game_over = -1;
  text("Cancel",width/4-50,height-25);
}

void credits() { //game development credits
  background(25,0,150);
  fill(255,220,0);
  textSize(48);
  text("Credits",width/2-250,height/7);
  fill(240);
  textSize(20);
  text("Designer : Alexander Maji",width/2-250,height/2-128);
  text("Developer : Alexander Maji",width/2-250,height/2-96);
  text("Tester : Alexander Maji",width/2-250,height/2-64);
  text("All images taken from Fandom",width/2-250,height/2-32);
  text("Audio credits (licensed Creative Commons 0): ",width/2-250,height/2);
  text("Scream.mp3, teleport.mp3 : Alexander Maji",width/2-250,height/2+32);
  text("All other audio from freesound.org",width/2-250,height/2+64);
  text("Inspired by 'The Backrooms'",width/2-250,height/2+96);
  text("Created for ICS3UR Computer Science Jan 2025",width/2-250,height/2+128);
  textSize(25);
  if(checkBtn(floor(width/4-50),height-25)) game_over = 3;
  text("Return",width/4-50,height-25);
}

void endText() { //ending text/epilogue of game
  background(25,0,150);
  fill(255,220,0);
  textSize(48);
  text("You survived",width/2-250,height/7);
  fill(240);
  textSize(20);
  text("Score: "+score,width/2+100,height/7);
  text("You wandered around what seems to be the",50,height/2-125);
  text("outside world. Everything seemed safe.",50,height/2-100);
  text("However...",50,height/2-75);
  text("Something still felt 'off', there was an odd",50,height/2-50);
  text("feeling, as if this was still in the Complex.",50,height/2-25);
  text("You think,'Is this a dream? Where am I?'",50,height/2);
  text("The walls around you feel like jelly.",50,height/2+25);
  text("You pass through them and return to Earth.",50,height/2+50);
  text("Your family and friends think you're missing.",50,height/2+100);
  text("You want to tell everyone about the Complex.",50,height/2+125);
  text("Forget it. Nobody will ever believe you.",50,height/2+150);
  text("They'll think you're crazy.",50,height/2+175);
  textSize(25);
  if(checkBtn(floor(width/4-50),height-25)) { //add score and autosave game
    score+=5000;
    saveGame();
    game_over = -1;
  }
  text("Return",width/4-50,height-25); 
  if(checkBtn(floor(width/1.5+25),height-25)) game_over=4;
  text("Credits",width/1.5+25,height-25); //show end credits
}

void checkButtons(int w, int h) { //check fixed-position buttons at start of the game
  fill(240);
  if(mouseX-w<175&&mouseX-w>-50&&h-mouseY<35&&h-mouseY>-5) {
   fill(255,200,0);
   text(">",w-32,h); 
   if(mousePressed) {
     if(h-height/2==0) { //new game
       select.play();
       wallArray = "";
       exits = "";
       loadSettings();
       generateWalls();
     }else if(h-height/2==50) { //continue
       select.play();
       loadSave(loadStrings("savefile.txt")); //load save file first
       generateWalls();
     }else if(h-height/2==100) { //options
       select.play();
       game_over = -2;
     }else if(h-height/2==200) { //quit game
       select.play();
       exit();
     }else{ //help
       select.play();
       game_over = -3;
     }
   }
  }
}

boolean checkBtn(int w, int h) { //check custom buttons (in options menu and pause menu)
  fill(240);
  if(mouseX-w<100&&mouseX-w>-25&&abs(mouseY-h)<12) {
   fill(255,200,0); 
   if(game_over==0) text(">",w-32,h); //show indicator only on pause menu
   if(mousePressed) {
     select.play();
     return true;
   }
  }
  return false;
}

boolean medBtn(int w, int h) { //used only to select rendering engine
  fill(240);
  if(mouseX-w<75&&mouseX-w>-10&&abs(mouseY-h)<12) {
   fill(255,200,0); 
   if(mousePressed) {
     select.play();
     return true;
   }
  }
  return false;
}

boolean smallBtn(int w, int h) { //used for - and + buttons in options menu
  fill(240);
  if(dist(mouseX,mouseY,w+8,h-4)<12) {
   fill(255,200,0); 
   if(mousePressed) {
     select.play();
     return true;
   }
  }
  return false;
}

void generateWalls() { //generate walls on map
  title.stop();
  wall = new int[mapX+1][mapY+1]; //reset wall array
  int wallCount = int(random(8,9)*(mapX*mapY*0.013)); //default number of walls
   //procedural generation
    switch(level) { //determine wall count based on level
     case 1: //open
       wallCount = int(random(8,9)*(mapX*mapY*0.0075));;
       break;
     case 2: //slightly cramped
       wallCount = int(random(8,9)*(mapX*mapY*0.018));;
       break;
     case 4: //more cramped
       wallCount = int(random(8,9)*(mapX*mapY*0.022));;
       break;
     case 5: //very open
       wallCount = int(random(8,9)*(mapX*mapY*0.0015));;
       break;
    }
    for(int i=0;i<wallCount;i+=1) {
       int sel = 0;
       switch(level) {
        case 4:
          sel = int(random(4,8)); //longer hallways and more cramped
          break;
        case 1:
          sel = int(random(0,3)); //pillars only
          break;
        case 3:
          sel = int(random(0,5)); //more open area, no "hallways"
          break;
        case 5:
          sel = 8; //large "structures"
          break;
        default:
          sel = int(random(0,8)); //all possible options except for large structures
          break;
       }
       int wx = int(random(2,mapX-1)); //wall position is randomized within map limits
       int wy = int(random(2,mapY-1));
       switch(sel) {
         case 0: //singular random wall
           wall[wx][wy]=1;
           break;
         case 5: //Wall N/S
           wall[wx][wy]=1;
           wall[wx+1][wy]=1;
           wall[wx-1][wy]=1;
           break;
         case 2: //Wall W/E
           wall[wx][wy]=1;
           wall[wx][wy+1]=1;
           wall[wx][wy-1]=1;
           break;
         case 1: //Pillars
           wall[wx+1][wy+1]=1;
           wall[wx-1][wy-1]=1;
           wall[wx+1][wy-1]=1;
           wall[wx-1][wy+1]=1;
           wall[wx][wy+1]=0;
           wall[wx][wy-1]=0;
           wall[wx+1][wy]=0;
           wall[wx-1][wy]=0;
           wall[wx][wy]=0;
           break;
         case 3: //Cross pillar
           wall[wx][wy+1]=1;
           wall[wx][wy-1]=1;
           wall[wx+1][wy]=1;
           wall[wx-1][wy]=1;
           wall[wx][wy]=1;
           wall[wx+1][wy+1]=0;
           wall[wx-1][wy-1]=0;
           wall[wx+1][wy-1]=0;
           wall[wx-1][wy+1]=0;
           break;
         case 4: //hallway N/S
           wall[wx][wy]=0;
           wall[wx+1][wy]=0;
           wall[wx-1][wy]=0;
           wall[wx+2][wy]=0;
           wall[wx-2][wy]=0;
           wall[wx][wy-1]=1;
           wall[wx+1][wy-1]=1;
           wall[wx-1][wy-1]=1;
           wall[wx][wy+1]=1;
           wall[wx+1][wy+1]=1;
           wall[wx-1][wy+1]=1;
           break;
         case 7: //hallway W/E
           wall[wx][wy]=0;
           wall[wx][wy+1]=0;
           wall[wx][wy-1]=0;
           wall[wx][wy+2]=0;
           wall[wx][wy-2]=0;
           wall[wx-1][wy]=1;
           wall[wx-1][wy+1]=1;
           wall[wx-1][wy-1]=1;
           wall[wx+1][wy]=1;
           wall[wx+1][wy+1]=1;
           wall[wx+1][wy-1]=1;
           break;
         case 8: //large structures
           wx = int(random(3,mapX-3)/4)*4+2;
           wy = int(random(3,mapY-3)/4)*4+2;
           wall[wx-2][wy]=1;
           wall[wx-2][wy+1]=1;
           wall[wx-2][wy-1]=1;
           wall[wx-2][wy+2]=1;
           wall[wx-2][wy-2]=1;
           wall[wx+2][wy+2]=1;
           wall[wx+2][wy+1]=1;
           wall[wx+2][wy-1]=1;
           wall[wx+2][wy]=1;
           wall[wx+2][wy-2]=1;
           wall[wx-1][wy-2]=1;
           wall[wx-1][wy+2]=1;
           wall[wx][wy-2]=1;
           wall[wx][wy+2]=1;
           wall[wx+1][wy-2]=1;
           wall[wx+1][wy+2]=1;
           wall[wx][wy]=1; //prevents spawning inside structures (there is no way out of them)
       }
  }
  for(int i=0;i<mapX;i++) { //generate nap borders
    wall[i][0]=1;
    wall[i][mapY]=1;
  }
  for(int i=0;i<mapY;i++) {
    wall[0][i]=1;
    wall[mapX][i]=1;
  }
  if(!wallArray.equals("null")&&wallArray.length()>1&&px!=0&&py!=0) loadWalls(); //load walls around player from file
  if(!exits.equals("null")&&exits.length()>1) { //load exits from file
    String[] doors = exits.split(" ");
    for(int i=0;i<doors.length;i++) {
      int[] exitPos = int(doors[i].split(",")); //process arrays
      wall[exitPos[0]][exitPos[1]]=4;
    }
  }else{
    for(int i=0;i<floor(mapX*mapY/65536);i++) { //generate exits based on map size
      dx = int(random(1,mapX)); //position of current exit
      dy = int(random(1,mapY));
      wall[dx][dy]=4; //set tile to exit portal
      exits+=nf(dx)+","+nf(dy)+" "; //save exits to array for access by map
    }
  }
  //set spawn
  respawn();
}

void loadWalls() {
  String[] walls = wallArray.split(" "); //space-separated coordinate pairs from file
  for(int wx=int(px/64)-oldRayCount*2;wx<=int(px/64)+oldRayCount*2;wx++) {
    for(int wy=int(py/64)-oldRayCount*2;wy<=int(py/64)+oldRayCount*2;wy++) {
      wall[wx][wy]=0; //clear walls around player first
    }
  }
  for(int i=0;i<walls.length;i++) { //load walls from array
    int[] wallPos = int(walls[i].split(","));
    wall[wallPos[0]][wallPos[1]]=1;
  }
}

void jumpScare() {
  PImage ent01 = loadImage("entity_"+id+".png"); //display image on timer
  imageMode(CENTER);
  tint(255,150+jumpScareState);
  image(ent01, width/2,height/2,width/1.5,height/1.5);
  jumpScareState -= 1;
  if(jumpScareState==0) entChase(); //chase sequence once timer runs out
}

void entChase() { //start entity chase
  //spawn entity away from player
  int mp = 64;
  if(int(random(0,2))==0) {
    mp = -64;
  }else{
    mp = 64;
  }
  do{
    ex = constrain(px+floor(random(256,512)/64)*mp,64,mapX*64); //ensure entity is not inside a wall
    ey = constrain(py+floor(random(256,512)/64)*mp,64,mapY*64);
  }while(wall[constrain(floor(ex/64),0,mapX)][constrain(floor(ey/64),0,mapY)]==1);
  ea = atan2(py-ey,px-ex); //Entity-player angle, -90 to 90 deg 
  //entity is not in a wall and not too close to player
}

void entMove() { //move entity (must be run in loop to work)
  if(em==1) {
    //pathfinding using entity direction
    entSpeed = 5+level/2+diff/2;
    if(((ex+cos(ea)*entSpeed >= 0) && (ex+cos(ea)*entSpeed <= mapX*64) && (ey+sin(ea)*entSpeed <= mapX*64) && (ey+sin(ea)*entSpeed >= 0))){ //check if within map limits
      if(wall[constrain(floor((ex+cos(ea)*entSpeed)/64),0,mapX)][constrain(floor((ey+sin(ea)*entSpeed)/64),0,mapY)]==1) { //a wall is ahead of entity
        if(ea>(-PI*3/4)&&ea<=-QUARTER_PI) { //W
          if(px<ex) { //player is left of entity
            ea=PI;
          }else{ //player is right of entity
            ea=0;
          }
        }
        else if(ea>-QUARTER_PI&&ea<=QUARTER_PI) { //N
          if(py<ey) { //player is left of entity
            ea=-HALF_PI;
          }else{ //player is right of entity
            ea=HALF_PI;
          }
        }
        else if(ea>QUARTER_PI&&ea<=(PI*3/4)) { //E
          if(px>ex) { //player is left of entity
            ea=0;
          }else{ //player is right of entity
            ea=PI;
          }
        }
        else{ //S
          if(py>ey) { //player is left of entity
            ea=HALF_PI;
          }else{ //player is right of entity
            ea=-HALF_PI;
          }
        } //if the entity is stuck in a dead end and cannot leave, consider it a feature (putting dead ends between player and entities is the only way to avoid being chased)
      } //NOT an if else, allowing entity to move after correcting angle
      if(wall[constrain(floor((ex+cos(ea)*entSpeed)/64),0,mapX)][constrain(floor((ey+sin(ea)*entSpeed)/64),0,mapY)]==0) { //entities only traverse open walls and avoid portals
        ex+=cos(ea)*entSpeed; //move entity at fixed speed if not in wall
        ey+=sin(ea)*entSpeed;
        ea = atan2(py-ey,px-ex); //Entity-player angle, -90 to 90 deg 
        step(entSpeed);
      }
    }
    ex=floor(ex/rayRes)*rayRes; //keep entity movement within raycast resolution
    ey=floor(ey/rayRes)*rayRes;
  }
  if(immune==0&&dist(ex,ey,px,py)<entSpeed) { //entity attack!
    health-=10*diff*id; //subtract health
    if(health>0) hurt.play(); //player screams
    ex = px+random(-64,64); //entity teleported away, may cause entity to be inside wall (intentional, prevents instant death in lower difficulties)
    ey = py+random(-64,64);;
  }
}

void respawn() {
 noise.stop();
 background(50,0,255);
 load.play(); //VCR cassette loading sound
 fill(240);
  text("PLAY",100,100);
  triangle(190,96,190,72,210,84);
 if(py==0||py==0) { //if player X/Y was not loaded from a save file
 do {
    px = random(mapX/4,mapX/1.5)*64;
    py = random(mapY/4,mapY/1.5)*64; //ensure player is has space around them in all 4 cardinal directions
  }while(wall[int(px/64)][int(py/64)]==1||wall[int(px/64)+1][int(py/64)]==1||wall[int(px/64)-1][int(py/64)]==1||wall[int(px/64)][int(py/64)-1]==1||wall[int(px/64)][int(py/64)+1]==1);
  pa = random(0,TWO_PI); //player angle in radians
  }
 game_over = 0;
 if(health<1) health=100; //restore health to player
 em = 1;
 delay(1000); //delay for visual reasons only
 if(level==4) { //level 4 has a stone/concrete floor
   step1 = new SoundFile(this,"step_s1.wav");
   step2 = new SoundFile(this,"step_s2.wav");
   step3 = new SoundFile(this,"step_s3.wav");
   alarm.amp(1);
   alarm.loop();
 }else if(level==1){ //level 1 has a stone floor
   step1 = new SoundFile(this,"step_s1.wav");
   step2 = new SoundFile(this,"step_s2.wav");
   step3 = new SoundFile(this,"step_s3.wav");
 }else{ //levels are carpeted by default
   if(level>4) birds.loop(); //levels 5+ are outdoors
   step1 = new SoundFile(this,"step_c1.wav");
   step2 = new SoundFile(this,"step_c2.wav");
   step3 = new SoundFile(this,"step_c3.wav");
 }
 step1.amp(0.8); //set volume for footstep sounds
 step2.amp(0.8);
 step3.amp(0.8);
}

/*LEVEL 5 IS NOT ACCESSIBLE! it is a "fallback" level to prevent the game from crashing if the level number in the save file is invalid
raydist() - Calculate distances to objects using raycasting (a semi-3D rendering technique first used in Wolfenstein 3D and other 1990s video games)
render() - Display objects to screen
controls() - Take inputs from player and display pause menu (since it ALWAYS overlays what is being rendered)
*/

void draw(){
  if(game_over==1) { //death
    render(); //rendering doesn't cause lag, raycasting does (which is why it does not run)
    gameOver(); //render TV static overlay
    controls(); 
    hum.stop(); //stop unnecessary audio
    alarm.stop(); 
    hum2.stop();
    birds.stop();
    noise.play(); //TV static sound
  }else if(game_over==2) { //ending cutscene
    noise.stop();
    hum.stop(); //stop unnecessary audio
    hum2.stop();
    alarm.stop();
    raydist();
    render();
    controls();
    ending();
  }else if(game_over==3) { //ending text
    noise.stop();
    hum.stop(); //stop unnecessary audio
    hum2.stop();
    alarm.stop();
    birds.stop();
    endText();
  }else if(game_over==4) { //credits
    noise.stop(); //stop unnecessary audio
    hum.stop();
    hum2.stop();
    alarm.stop();
    birds.stop();
    credits();
  }else if(game_over!=0) { //title screen
    switch(game_over) { //select page of title screen
      case -2:
        options();
        break;
      case -3:
        help();
        break;
      default:
        titleScreen(); //main page
        break;
    }
  }else {
    load.stop(); //run game normally
    stroke(100);
    raydist();
    render();
    controls();
    if(level==4){
      if(!alarm.isPlaying()) alarm.loop(); //play alarm noise on level 4
      noise.stop(); //stop unnecessary audio
      hum.stop();
      hum2.stop();
      birds.stop();
    }else if(level>4){ //"outside world" levels (only exist to avoid save file issues)
      if(!birds.isPlaying()) birds.loop();
      noise.stop(); //stop unnecessary audio
      hum.stop();
      hum2.stop();
      alarm.stop();
    }else{
      noise.stop(); //stop unnecessary audio
      alarm.stop(); 
      birds.stop();
       hum.freq(60); //play AC hum ambience
       hum2.freq(120);
      hum.play(); 
      hum2.play();
    }
  }
}

void crtScan(int scanY) { //television-style scan lines (aesthetic purposes)
 stroke(random(175,255),100);
 line(0,scanY,width,scanY);
}

void gameOver() { //draw TV static on screen
 scream.stop();
 for(int h=0;h<height;h++) {
  for(int w=0;w<width;w++) {
   color c = color(int(random(75,255)));
   set(w,h,c); 
  }
 }
 text("Click anywhere to respawn",width/2-200,height-25);
 if(mousePressed) {
   px=0;
   py=0;
   respawn();
 }
}

void noiseRoof(int r, int g, int b, int p) { //generate ceiling textures using noise (resembles popcorn ceilings)
 for(int h=0;h<height/2;h++) {
  for(int w=0;w<width;w++) {
   color c = color(random(r-p,r+p),random(g-p,g+p),random(b-p,b+p));
   set(w,h,c); 
  }
 }
}

void noiseFloor(int r, int g, int b, int p) { //use noise to generate a carpet-like floor surface
 for(int h=height/2;h<height;h++) {
  for(int w=0;w<width;w++) {
   float rdiff = random(-p,p);
   color c = color(r+rdiff,g+rdiff,b+rdiff);
   set(w,h,c); 
  }
 }
}

void loadmap() { //load 2D map to display to player
 for(int h=int(px/64)-30;h<int(px/64)+30;h++) {
  if(h<0) h=0;
  if(h>8192) h=8192;
  for(int w=int(py/64)-30;w<int(py/64)+30;w++) {
  if(w<0) w=0; //constrain variables to array
  if(w>8192) w=8192;
   fill(0);
   noStroke();
   if(wall[h][w]==1) rect(map(w,int(py/64)-30,int(py/64)+30,width/2-(height/2)+25,width/2+height/2-25),map(h,int(px/64)+30,int(px/64)-30,25,height-25)-height/65,height/65,height/65); //regular walls are black
   fill(20,200,0);
   if(wall[h][w]==4) rect(map(w,int(py/64)-30,int(py/64)+30,width/2-(height/2)+25,width/2+height/2-25),map(h,int(px/64)+30,int(px/64)-30,25,height-25)-height/65,height/65,height/65); //exits are green
  }
 } 
 fill(20,0,200);
 rect(map(py/64,py/64-30,py/64+30,width/2-(height/2)+25,width/2+height/2-25),map(px/64,px/64-30,px/64+30,25,height-25)-height/60,height/60,height/60); //player is blue
 fill(200,20,0);
 rect(map(ey/64,int(py/64)-30,int(py/64)+30,width/2-(height/2)+25,width/2+height/2-25),map(ex/64,int(px/64)+30,int(px/64)-30,25,height-25)-height/65,height/65,height/65); //entity is red
}

void vmap() { //draw map background, north arrow, and allow player to view map
 fill(0);
 rect(width/2-(height/2)-25,20,height+5,height-40);
 fill(220,210,200);
 rect(width/2-(height/2)-20,25,height-5,height-50);
 fill(0);
 rect(width/2-(height/2)+20,25,5,height-50);
 text("^",width/2-(height/2)-8,50);
 text("N",width/2-(height/2)-8,60);
 loadmap();
}

void raydist(){ //raycasting
  rn=0;
  for(r=-PI/6;r<PI/6;r=r+(PI/3)/width){ //loop through player FOV (scren width = PI/3 radians)
    ray[rn]=-1; //reset distance variables
    ray_d[rn]=-1;
    ray_e[rn]=-1;
    //Raycast walls in North/South direction
    if(sin(pa+r)<0){ //determine X and Y increment constants based on player direction
      ya=floor(py/64)*64-0.01;
      xc=64/tan(-(pa+r));
      yc=-64;
    }
    else{
      ya=floor(py/64)*64+64.02;
      xc=64/tan(pa+r);
      yc=64;
    }
    xa=px+((py-ya)/tan(-(pa+r)));
    oldxa=xa; //increment scan X and Y position
    oldya=ya;
    //This is the "imprecise" loop, scans are done in intervals of 64 (every whole wall). Allows for object smoothness.
    for(int i=0;i<rayCount;i++){ //repeat for the render distance, keep X and Y scan position within map constraints
      if(xa>0 &&xa<mapX*64){
        if(ya>0 &&ya<mapY*64){
          if(wall[floor(xa/64)][floor(ya/64)]==1){ //ray hits a wall
            rd=sqrt(sq(xa-px)+sq(ya-py)); //get distance to object
            if(ray[rn]==-1){ //if distance is new, save it
              ray[rn]=rd*cos(r);
            }
            else{
              if(rd<ray[rn]/cos(r)){ //if distance found is shorter than previous, save it
                ray[rn]=rd*cos(r);
              }
            }
          }
          if(wall[floor(xa/64)][floor(ya/64)]==4){ //same logic for portals
            rd=sqrt(sq(xa-px)+sq(ya-py));
            if(ray_d[rn]==-1){
              ray_d[rn]=rd*cos(r);
            }
            else{
              if(rd<ray_d[rn]/cos(r)){
                ray_d[rn]=rd*cos(r);
              }
            }
              dx = floor(xa/64);
              dy = floor(ya/64);
          }
          if(dist(xa,ya,ex,ey)<dist(ex,ey,px,py)/512){ //Casting gets less precise the further awal from the entity the player is (prevents flickering)
            rd=sqrt(sq(xa-px)+sq(ya-py)); //same logic for raycasting entities
            if(ray_e[rn]==-1){
              ray_e[rn]=rd*cos(r);
            }
            else{
              if(rd<ray_e[rn]/cos(r)){
                ray_e[rn]=rd*cos(r);
              }
            }
          }
        }
      }
      xa=oldxa+xc; //increment raycast variables
      ya=oldya+yc;
      oldxa=xa;
      oldya=ya;
    }
  
    //Raycast walls in East/West direction
    if(sin(pa+PI/2+r)<0){ //same logic as before to determine starting point of rays
      xa=floor(px/64)*64-0.01;
      yc=64*tan(-(pa+r));
      xc=-64;
    }
    else{
      xa=floor(px/64)*64+64.01;
      yc=64*tan(pa+r);
      xc=64;
    }
    ya=py+((px-xa)/tan(pa+PI/2+r));
    oldxa=xa;
    oldya=ya; 

    for(int i=0;i<rayCount;i++){ //repeat for render distance, keep scan coordinates within map limits
      if(xa>0 &&xa<mapX*64){
        if(ya>0 &&ya<mapY*64){
          if(wall[floor(xa/64)][floor(ya/64)]==1){ //if wall is at scan position
            rd=sqrt(sq(xa-px)+sq(ya-py)); //get distance
            if(ray[rn]==-1){ //if distance is new, save it
              ray[rn]=rd*cos(r);
            }
            else{
              if(rd<ray[rn]/cos(r)){ //if distance is shorter than before, save it
                ray[rn]=rd*cos(r);
              }
            }
          }if(wall[floor(xa/64)][floor(ya/64)]==4){ //same logic for portals
            rd=sqrt(sq(xa-px)+sq(ya-py));
            if(ray_d[rn]==-1){
              ray_d[rn]=rd*cos(r);
            }
            else{
              if(rd<ray_d[rn]/cos(r)){
                ray_d[rn]=rd*cos(r);
              }
            }
              dx = floor(xa/64);
              dy = floor(ya/64);
          }
          if(dist(xa,ya,ex,ey)<dist(ex,ey,px,py)/512){ //same logic for entities
            rd=sqrt(sq(xa-px)+sq(ya-py));
            if(ray_e[rn]==-1){
              ray_e[rn]=rd*cos(r);
            }
            else{
              if(rd<ray_e[rn]/cos(r)){
                ray_e[rn]=rd*cos(r);
              }
            }
          }
        }
      }
      xa=oldxa+xc; //increment variables
      ya=oldya+yc;
      oldxa=xa;
      oldya=ya;
    }
    rn++; //increment horizontal position on screen
  }
  rn=0;
  for(r=-PI/6;r<PI/6;r=r+(PI/3)/width){ //"Precise" loop, used to find precise position of entities and fill in gaps on certain sides of walls (a bug that I couldn't find a proper solution for)
    ray_e[rn]=-1; //only reset entity position, since it needs to be precise
    //HORIZONTAL SCAN 
    if(sin(pa+r)<0){ //use player direction and some trigonometry to find
      ya=floor(py/rayRes)*rayRes-0.01; //rayRes is how many 64ths of a wall is the precision. Currently it is 1/64 of a wall (determined as optimal value during testing)
      xc=rayRes/tan(-(pa+r));
      yc=-rayRes;
    }
    else{
      ya=floor(py/rayRes)*rayRes+rayRes+0.01;
      xc=rayRes/tan(pa+r);
      yc=rayRes; //increments are 1/64th of a wall, allowing for precision (but less smoothness and more lag)
    }
    xa=px+((py-ya)/tan(-(pa+r)));
    oldxa=xa;
    oldya=ya; //set starting position for scanning

    for(int i=0;i<rayCount*64;i++){ //repeat for render distance 
      if(xa>0 &&xa<mapX*64){
        if(ya>0 &&ya<mapY*64){
          if(wall[floor(xa/64)][floor(ya/64)]==1){ //if wall hit by ray
            rd=sqrt(sq(xa-px)+sq(ya-py)); //get distance 
            if(ray[rn]==-1){ //if distance is new, save it
              ray[rn]=rd*cos(r);
            }
            else{
              if(rd<ray[rn]/cos(r)){ //if distance shorter than previous distance, save it
                ray[rn]=rd*cos(r);
              }
            }
          }
          if(wall[floor(xa/64)][floor(ya/64)]==4){ //same logic for portals
            rd=sqrt(sq(xa-px)+sq(ya-py));
            if(ray_d[rn]==-1){
              ray_d[rn]=rd*cos(r);
            }
            else{
              if(rd<ray_d[rn]/cos(r)){
                ray_d[rn]=rd*cos(r);
              }
            }
          }
          if(dist(xa,ya,ex,ey)<dist(ex,ey,px,py)/512){ //same logic for entities. Casting is less precise as entity is further from player (prevents entities from flickering)
            rd=sqrt(sq(xa-px)+sq(ya-py)); //get distance to entity
            if(ray_e[rn]==-1){ //if distance is new, save it
              ray_e[rn]=rd*cos(r);
            }
            else{
              if(rd<ray_e[rn]/cos(r)){ //if distance is shorter than previous, save it
                ray_e[rn]=rd*cos(r);
              }
            }
          }
        }
      }
      xa=oldxa+xc; //increment scanning coordinates slightly
      ya=oldya+yc;
      oldxa=xa;
      oldya=ya;
    }
  
    //VERTICAL SCAN
    if(sin(pa+PI/2+r)<0){ //determine starting position and increments
      xa=floor(px/rayRes)*rayRes-0.01;
      yc=rayRes*tan(-(pa+r));
      xc=-rayRes;
    }
    else{
      xa=floor(px/rayRes)*rayRes+rayRes+0.01; //scans every 1/64th of a wall (precise, but less smooth)
      yc=rayRes*tan(pa+r);
      xc=rayRes;
    }
    ya=py+((px-xa)/tan(pa+PI/2+r));
    oldxa=xa;
    oldya=ya;

    for(int i=0;i<rayCount*64;i++){ //repeat for render distance, keep scan position within map limits
      if(xa>0 &&xa<mapX*64){
        if(ya>0 &&ya<mapY*64){
          if(wall[floor(xa/64)][floor(ya/64)]==1){ //if wall found by ray
            rd=sqrt(sq(xa-px)+sq(ya-py)); //get distance to wall
            if(ray[rn]==-1){
              ray[rn]=rd*cos(r); //if distance is new, save it 
            }
            else{
              if(rd<ray[rn]/cos(r)){ //if distance shorter than previous, save it
                ray[rn]=rd*cos(r);
              }
            }
          }
          if(wall[floor(xa/64)][floor(ya/64)]==4){ //same logic for portals
            rd=sqrt(sq(xa-px)+sq(ya-py));
            if(ray_d[rn]==-1){
              ray_d[rn]=rd*cos(r);
            }
            else{
              if(rd<ray_d[rn]/cos(r)){
                ray_d[rn]=rd*cos(r);
              }
            }
          }
          if(dist(xa,ya,ex,ey)<dist(ex,ey,px,py)/512){ //same logic for entity distance
            rd=sqrt(sq(xa-px)+sq(ya-py));
            if(ray_e[rn]==-1){
              ray_e[rn]=rd*cos(r);
            }
            else{
              if(rd<ray_e[rn]/cos(r)){
                ray_e[rn]=rd*cos(r);
              }
            }
          }
        }
      }
      xa=oldxa+xc; //increment the coordinates by 1/64th of a wall for precision
      ya=oldya+yc;
      oldxa=xa;
      oldya=ya;
    }
    rn++; //increment ray number (vertical position on screen)
  }
}

void render() { //display images
  noStroke();
  switch(level) { //determine colours based on level and light colour (random value when game starts)
    case 0:
      fill(200-lightCol,200-lightCol,175-lightCol); //roof
      rect(0,0,width,height/2);
      noiseFloor(150-lightCol,150-lightCol,100-lightCol,20);
      break;
    case 4:
      fill(200-lightCol,150-lightCol,150-lightCol); //roof
      rect(0,0,width,height/2);
      fill(150-lightCol,50-lightCol,50-lightCol);//floor
      rect(0,height/2,width,height/2); break;
    case 1:
      noiseRoof(200-lightCol,200-lightCol,200-lightCol,20);
      fill(130-lightCol,125-lightCol,120-lightCol);//floor
      rect(0,height/2,width,height/2); break;
    case 3:
      fill(215-lightCol,230-lightCol,230-lightCol); //roof
      rect(0,0,width,height/2);
      noiseFloor(100-lightCol,150-lightCol,200-lightCol,30); break;
    case 2:
      noiseRoof(200-lightCol,200-lightCol,180-lightCol,15);
      noiseFloor(150-lightCol,130-lightCol,100-lightCol,15); break;
    default:
      fill(175-lightCol,200-lightCol,215-lightCol); //roof
      rect(0,0,width,height/2);
      noiseFloor(125-lightCol,150-lightCol,100-lightCol,30); break;
  }
  for(int rn=0;rn<width;rn++){ //draw walls
    if(ray[rn]>0){
      float wh=64/ray[rn]*255; //determine height based on level
      float wallCol = random(175,200); //random wall colour variance to add rough texture to them
      switch(level) { //determine colour based on level
        case 0:
          stroke(wallCol-lightCol,wallCol-lightCol,100-lightCol); break;
        case 4:
          stroke(wallCol-lightCol,125-lightCol,100-lightCol);break;
        case 1:
          stroke(wallCol-lightCol,wallCol-lightCol,wallCol-lightCol);break;
        case 3:
          stroke(15+wallCol-lightCol,220-lightCol,220-lightCol);break;
        case 2:
          stroke(220-lightCol,220-lightCol,200-lightCol);break; //smooth walls on level 2 (they look like paper)
        default:
          stroke(wallCol-40-lightCol,wallCol-25-lightCol,wallCol-40-lightCol);
          line(rn,height/2-wh*1.5,rn,height/2-wh); //tall ceilings on higher levels
          break;
      }
      line(rn,height/2+wh,rn,height/2-wh); //draw wall based on center of screen, symettrical height
    }
    if(ray_d[rn]>0){ //draw portals
      if(ray_d[rn]<ray[rn]) {
        float wh=64/ray_d[rn]*255; //draw floor/ceiling areas with colours of next level, these are the walls/edges of the portal itself
        switch(level) {
          default:
            stroke(175-lightCol,200-lightCol,215-lightCol); //sky
            line(rn,height/2,rn,height/2-wh);
            stroke(125-lightCol,150-lightCol,100-lightCol);
            line(rn,height/2+wh,rn,height/2); //ground
            break;
          case 3:
            stroke(200-lightCol,150-lightCol,150-lightCol); //roof
            line(rn,height/2,rn,height/2-wh);
            stroke(150-lightCol,50-lightCol,50-lightCol);//floor
            line(rn,height/2+wh,rn,height/2); break;
          case 0:
            stroke(200-lightCol,200-lightCol,200-lightCol);
            line(rn,height/2,rn,height/2-wh); //roof
            stroke(130-lightCol,125-lightCol,120-lightCol);//floor
            line(rn,height/2+wh,rn,height/2); break;
          case 2:
            stroke(215-lightCol,230-lightCol,230-lightCol); //roof
            line(rn,height/2,rn,height/2-wh);
            stroke(100-lightCol,150-lightCol,200-lightCol); //floor
            line(rn,height/2+wh,rn,height/2); break;
          case 1:
            stroke(200-lightCol,200-lightCol,180-lightCol); //roof
            line(rn,height/2,rn,height/2-wh);
            stroke(150-lightCol,130-lightCol,100-lightCol); //floor
            line(rn,height/2+wh,rn,height/2); break;
        }
        wh=64/ray[rn]*255; //draw walls
        float wallCol = random(175,200); //aesthetic reasons
        switch(level) { //preview next level wall colour through the "portal" using existing "normal" walls
          default:
            stroke(wallCol-40-lightCol,wallCol-25-lightCol,wallCol-40-lightCol); break;
          case 1:
            stroke(220-lightCol,220-lightCol,200-lightCol); break;
          case 3:
            stroke(wallCol-lightCol,125-lightCol,100-lightCol);break;
          case 0:
            stroke(wallCol-lightCol,wallCol-lightCol,wallCol-lightCol);break;
          case 2:
            stroke(15+wallCol-lightCol,220-lightCol,220-lightCol);break;
        }
        line(rn,height/2+wh,rn,height/2-wh); //same logic for walls as previously
      }
    }
  }for(int rn=0;rn<width;rn++){ //draw entity
    if(ray_e[rn]>0&&ray[rn]>ray_e[rn]) { //make sure entity is not behind a wall
     PImage entC = loadImage("entity_"+id+".png"); //load image based on entity type
     imageMode(CENTER);
     float wh=64/ray_e[rn]*255; //get entity height (same logic as with wall height)
     image(entC,rn,height/2,2*wh,2*wh); //display image
    }
  } 
  if(int(random(0,1000-(diff*50)))==0 && pSpeed>4 && jumpScareState>=0 && dist(ex,ey,px,py)>1024) { //start jumpscare at random if the plater is not sneaking, jumpscares are enabled, and entity is far away
    id = floor(random(1,3)); //set random entity ID
    jumpScareState = int(frameRate/2); //set jumpscare state/timer
    if(id==2) {
      scream.play(); //play scream of Entity 2
    }else{
      roar.play(); //play roar of Entity 1
    }
  }
  if(jumpScareState>0) jumpScare(); //1 jumpscare every 600 frames (draws image)
  entMove(); //move entity
  noStroke();
  fill(25);
  rect(width-225,height-20,200,10); //health bar background
  fill(constrain(300-health*2,0,200),constrain(50+health*3,0,200),50+(health/2));
  rect(width-225,height-20,health*2,10); //health bar
  fill(240);
  if(keys[com]==false) { //draw the time overlay if the menu isn't open
  textSize(32);
  String min = "",sec = "";
  if(minute()<10) min = "0"; //correct time values (show 01 instead of 1, etc.) for minutes and seconds
  if(second()<10) sec = "0";
  text(month()+"/"+day()+"/"+(year()-yearMod),width-225,height-55); //VHS style date/time stamp at bottom right corner
  text(hour()+":"+min+minute()+":"+sec+second(),width-225,height-25);
  }
  textSize(25);
  if(health<1) game_over=1; //player dies if health less than 1
  crtScan(int(random(0,height))); //crt television overlay effect
}

void disp() {
  //display mode for debugging purposes, displays primary variables that change often
  text("WALL ("+int(px/64)+","+int(py/64)+")  FACING "+dir,5,50); 
  text("POS ("+int(px)+","+int(py)+") "+pa+" RAD",5,25); 
  text("ENT POS ("+int(ex)+","+int(ey)+") "+ea+" RAD",5,75);
  text("XA, YA ("+int(xa)+","+int(ya)+") OLD ("+int(oldxa)+","+int(oldya)+") ",5,100);
  text("XC, YC ("+int(xc)+","+int(yc)+") ANG, DIST "+r+","+int(rd)+") ",5,125); 
  text("ENT.DIST "+dist(ex,ey,px,py)+" "+int(frameRate)+" FPS",5,150);
  text("FACING EXIT: WALL("+dx+","+dy+")",5,175); 
}

String saveWalls() { //loads walls around player and saves them to an array-like string (which is then saved to file)
  String walls = "";
  for(int wx=int(px/64)-rayCount*2;wx<=int(px/64)+rayCount*2;wx++) {
    for(int wy=int(py/64)-rayCount*2;wy<=int(py/64)+rayCount*2;wy++) {
      if(wall[wx][wy]==1) {
        walls+=wx+","+wy;
        if(wx!=int(px/64)+rayCount*2||wy!=int(py/64)+rayCount*2) walls+=" ";
      }
    }
  }
  return walls;
}

void saveGame() { //saves all parameters to file
 //save backup copy of old save file when saving game
 String[] saveFile = loadStrings("savefile.txt");
 saveStrings("data/savefile_old_"+year()+month()+day()+".txt",saveFile);
 saveFile = new String[20]; //reset save file variable
 saveFile[0] = nf(width); //screen size
 saveFile[1] = nf(height);
 saveFile[2] = nf(frm); //frame rate
 saveFile[3] = nf(renderer); //rendering engine
 saveFile[4] = nf(mapX); //map size
 saveFile[5] = nf(mapY);
 saveFile[6] = nf(rayCount); //render distance
 saveFile[7] = saveWalls(); //get wall positions from other method
 saveFile[8] = exits; //exit door location(s)
 saveFile[9] = nf(int(dev)); //developer mode is converted from boolean to int
 saveFile[10] = nf(diff); //difficulty level
 saveFile[11] = nf(yearMod); //year from overlay
 saveFile[12] = nf(score); //score
 saveFile[13] = nf(level); //level
 saveFile[14] = nf(health); //player health
 saveFile[15] = nf(rayCount); //save distance (for laoding walls)
 saveFile[16] = nf(px); //player position and angle
 saveFile[17] = nf(py);
 saveFile[18] = nf(pa);
 saveFile[19] = nf(vol); //audio master volume
 saveStrings("data/savefile.txt",saveFile);
 text("Successfully saved to file.",5,height-25);
}

void saveSettings() { //saves settings ONLY to file
 String[] saveFile = loadStrings("savefile.txt");
 saveStrings("data/savefile_old_"+year()+month()+day()+".txt",saveFile);
 saveFile[0] = nf(screenW); //screen size
 saveFile[1] = nf(screenH);
 saveFile[2] = nf(frm); //frame rate
 saveFile[3] = nf(renderer); //rendering engine
 saveFile[4] = nf(mapX); //map size
 saveFile[5] = nf(mapY);
 saveFile[6] = nf(rayCount); //render distance
 saveFile[10] = nf(diff); //difficulty
 saveFile[19] = nf(vol); //master volume
 saveStrings("data/savefile.txt",saveFile);
 text("Restart game to apply.",width/2-25,40); 
}

void step(float speed) { //plays step sounds
  int step=0;
  do{
   step = int(random(0,3)); //random step sound
  }while(step==oldStep);
 if(frameCount%int(frm/int(speed/2)) == 0) { //function runs at certain time interval based on provided movemnt speed
    step1.stop();
    step2.stop(); //stop existing step sounds
    step3.stop();
    if(step==0) { //based on random number, play correct audio file
      step1.play();
    }else if(step==1){
      step2.play();
    }else{
      step3.play();
    } 
  oldStep=step; //prevents playing same file twice
 }
}

void controls(){ //process inputs
  if(keys[com]!=true) {
  if(wall[int(px/64)][int(py/64)]==4) { //player finds a portal
      level++; //next level, score increased
      score+=1000;
      px=0; //reset player position and walls from save file
      py=0;
      wallArray="";
      exits="";
      wall = new int[mapX+1][mapY+1]; //clear all walls on map
      teleport.play(); //teleportation sound effect
      generateWalls(); //generate new walls and respawn player
      if(level==5) { //start ending cutscene if the new level is level 5
        game_over = 2;
        title.loop();
      }
  }
  if(keys[up]==true && ((px+cos(pa)*pSpeed >= 0) && (px+cos(pa)*pSpeed <= mapX*64) && (py+sin(pa)*pSpeed <= mapX*64) && (py+sin(pa)*pSpeed >= 0)) && wall[floor((px+cos(pa)*pSpeed)/64)][floor((py+sin(pa)*pSpeed)/64)]!=1){
    px=px+cos(pa)*pSpeed; //move forward if within map limits and not about to hit a wall
    py=py+sin(pa)*pSpeed;
    step(pSpeed);
    score++; //increments score by 1 for just walking
  }
  if(keys[down]==true && ((px-cos(pa)*pSpeed >= 0) && (px-cos(pa)*pSpeed <= mapX*64) && (py-sin(pa)*pSpeed <= mapX*64) && (py-sin(pa)*pSpeed >= 0)) && wall[floor((px-cos(pa)*pSpeed)/64)][floor((py-sin(pa)*pSpeed)/64)]!=1){
    px=px-cos(pa)*pSpeed; //move backward if within map limits and not about to hit a wall
    py=py-sin(pa)*pSpeed;
    step(pSpeed);
  }
  if(keys[left]==true){ //rotate left
    pa-=.1;
  }
  if(keys[right]==true){ //rotate right
    pa+=.1;
  }
  if(pa>PI) pa-=TWO_PI; //correct player angle (keeps it in range from -PI to PI radians)
  if(pa<-PI) pa+=TWO_PI;
  //direction
  if(pa>(-PI*3/4)&&pa<=-QUARTER_PI) { //determine player cardinal direction based on approximate angle
    dir="WEST";
  }
  else if(pa>-QUARTER_PI&&pa<=QUARTER_PI) {
    dir="NORTH";
  }
  else if(pa>QUARTER_PI&&pa<=(PI*3/4)) {
    dir="EAST";
  }
  else if(pa>PI*(3/4)||pa<=-PI*(3/4)){
    dir="SOUTH";
  }
  if(dsp==1) {
    disp(); //debug display
  }else if(dsp==0){
  if(keys[space]==true) { //position display
  if(pSpeed>5) {
     text("WALL ("+int(px/64)+","+int(py/64)+") "+nf(pa,0,3)+" rad",5,25); //wall position shown if running
     text("FACING EXIT: WALL("+dx+","+dy+")",5,70); //nearest exit wall position
   }else{
     text("POS ("+int(px)+","+int(py)+") "+nf(pa,0,3)+" rad",5,25); //normal position shown if walking/sneaking
     text("FACING EXIT: POS("+dx*64+","+dy*64+")",5,70); //wall position multiplied to precise value
   }
   text("FACING "+dir,5,48); //cardinal direction
  }
  }
  }else{
     //process developer commands and pause menu
     textSize(25);
     String[] command = split(cmd," "); //get command
     if(dev) { //developer commands only
     char cur = (second()*5)%2==0 ? '_' : ' ';
     text("/"+comm+cur,5,height-5);
     switch(command[0]) {
        case "tp":
          if(command.length>1) {
            if(float(command[1])>=1&&float(command[1])<mapX*64) { //teleport command chaecks if positions are valid and teleports player to precise coordinate
              px = float(command[1]);
            }else{
              text("X position out of range. (1 <= X < +"+(mapX*64)+")",5,height-65);
            }
          }
          if(command.length>2) {
            if(float(command[2])>=1&&float(command[2])<mapY*64) {
              py = float(command[2]);
            }else{
              text("Y position out of range. (1 <= Y <"+(mapY*64)+")",5,height-45);
            }
          }
          if(command.length>3) pa = float(command[3]);
          text("Teleported self to POS("+px+","+py+")",5,height-25);
          break;
        case "tpw":
          if(command.length>1) {
            if(float(command[1])>=1&&float(command[1])<mapX) { //teleport command chaecks if positions are valid and teleports player to WALL coordinate
              px = float(command[1])*64;
            }else{
              text("X position out of range. (1 <= X < "+mapX+")",5,height-65);
            }
          }
          if(command.length>2) {
            if(float(command[2])>=1&&float(command[2])<mapY) {
              py = float(command[2])*64;
            }else{
              text("Y position out of range. (1 <= Y < "+mapY+")",5,height-45);
            }
          }
          if(command.length>3) pa = float(command[3]);
          text("Teleported self to WALL("+px/64+","+py/64+")",5,height-25);
          break;
         case "etp":
          if(command.length>1) ex = float(command[1]); //entity teleport command chaecks if positions are valid and teleports entity to precise coordinate
          if(command.length>2) ey = float(command[2]);
          if(command.length>3) ea = float(command[3]);
          text("Teleported entity to POS("+ex+","+ey+")",5,height-25);
          break;
        case "etw":
          if(command.length>1) ex = float(command[1])*64; //entity teleport command chaecks if positions are valid and teleports entity to WALL coordinate
          if(command.length>2) ey = float(command[2])*64;
          if(command.length>3) ea = float(command[3])*64;
          text("Teleported entity to WALL("+ex+","+ey+")",5,height-25);
          break;
        case "imm":
          if(command.length>1) immune = int(command[1]); //sets entity immunity flag to provided parameter (0 = not immune, 1 = immune to entity attacks)
          text("Entity immunity set to "+immune,5,height-25);
          break;
        case "jst":
          if(command.length>1) jumpScareState = int(command[1]); //sets jumpscare state to provided parameter, negative values disable jumpscares
          text("Jumpscare state set to "+jumpScareState,5,height-25);
          break;
        case "id":
          if(command.length>1) id = int(command[1]); //sets entity image ID to provided parameter, was only used for testing (will cause issues if a number other than 1 or 2 is given)
          text("Entity ID set to "+id,5,height-25);
          break;
        case "em":
          if(command.length>1) em = int(command[1]); //enables/disables entity movement 
          text("Entity movement permission set to "+em,5,height-25);
          break;
        case "es":
          if(command.length>1) entSpeed = float(command[1]); //sets entity speed to provided value
          text("Entity speed set to "+entSpeed,5,height-25);
          break;
        case "hlt":
          if(command.length>1) health = int(command[1]); //sets health to provided value
          text("Health set to "+health,5,height-25);
          break;
        case "lvl":
          if(command.length>1) level = int(command[1]); //sets level to provided value without regenerating walls or respawning player
          text("Level set to "+level,5,height-25);
          break;
        case "dsp":
          if(command.length>1) { //sets displa mode to value
          dsp = int(command[1]);
          }
          else {
          disp();
          }
          break;
        case "die": //sets game over flag to provided value, used for testing
          if(command.length>1) {
          game_over = int(command[1]);
          }
          else {
          gameOver(); //briefly displays game over screen
          }
          break;
        case "map": //displays map
        vmap();
        break;
      case "save": //saves game
        saveGame();
        break;
      case "help":
      case "h": //describes other commands to user
        text("/die (Optional: 0-1 toggle)- Instant death",5,height-305);
        text("/dsp (Optional: 0-1toggle )- Dev display",5,height-285);
        text("/es {float value) - Set entity speed",5,height-245);
        text("/em {float value) - Toggle entity movement",5,height-265);
        text("/etp (X) (Y) - Precise entity tp",5,height-225);
        text("/etw (X) (Y) - Wall entity tp",5,height-205);
        text("/hlt (int value) - Set player health",5,height-185);
        text("/id (int 1-2) - Set entity ID",5,height-155);
        text("/imm (int 0-1) - Toggle entity immunity",5,height-145);
        text("/jst (int value) - Set jumpscare state",5,height-125);
        text("/lvl (int value) - Set level (won't edit walls)",5,height-105);
        text("/map - View map",5,height-85);
        text("/save - Save game to file",5,height-65);
        text("/tp (X) (Y) (Opt.: Ang) - Precise Teleport",5,height-45);
        text("/tpw (X) (Y) (Opt.: Angle) - Wall Teleport",5,height-25);
        break;    
      case "3838404037393739ba": //cheat code
        text("Developer mode enabled.",32,height-25);
        dev=true;
        break;
      case "": //does not run empty commands
        break;
      default: //handles invalid commands
        text("Invalid command. Try /h or /help.",32,height-25);
        break;
      }
     }else{
       //user-friendly pause menu
       textSize(32);
       fill(50,0,150);
       rect(width/2-150,height/2-150,300,200); //menu background
       fill(240);
       text("MENU",width/2-40,height/2-110);
       textSize(25); //draw interactive buttons
       if(checkBtn(width/2-75,height/2-60)) cmd = "map";
       text("View Map",width/2-75,height/2-60);
       if(checkBtn(width/2-75,height/2-20)) cmd = "save";
       text("Save game",width/2-75,height/2-20);
       if(checkBtn(width/2-75,height/2+20)) exit();
       text("Quit game",width/2-75,height/2+20);
       fill(240);
       textSize(20);
       text("Press DELETE to cancel",5,height-5);
     switch(command[0]) { //command is set by buttons (text also works, but is not visible)
      case "map":
        vmap();
        break;
      case "save":
        saveGame();
        break;
      case "help":
      case "h": //unused code, kept it just in case
          text("/map - View map",5,height-45);
          text("/save - Save game to file",5,height-25);
        break;    
      case "3838404037393739ba": //cheat code to access developer mode (up, up, down down, left, right, left, right, b, a)
        text("Developer mode enabled.",32,height-25);
        dev=true;
        break;
      case "":
        break;
      default:
        break; //prevents running empty or invalid commands
      }
     }
     if(frameCount%2==0) cmdTimer++; //timer to prevent instantly closing menus
  }
}

void keyPressed() {
  if(keys[com]!=true&&game_over!=2) { //move player only if menu is not open and cutscene is not playing
  if (keyCode == UP || key == 'w' || key == 'W') {
    keys[up] = true;
  }  
  else if(keyCode == DOWN || key == 's' || key == 'S') {
    keys[down] = true;
  } 

  else if(keyCode == LEFT || key == 'a' || key == 'A') {
    keys[left] = true;
  } 
  else if (keyCode == RIGHT || key == 'd' || key == 'D') {
    keys[right] = true;
  }
  else if (keyCode == SHIFT) {
   pSpeed = 9; 
  }
  else if (keyCode == CONTROL) {
   pSpeed = 4; 
  }
  else if (key == ' ') {
   keys[space] = true; 
  }
  else if (key == '/') {
   keys[com] = true; 
  }
  }else{ //otherwise take input as text (dev commands)
   if(keyCode == BACKSPACE && comm.length()>0) comm = comm.substring( 0, comm.length()-1 );
   else if(keyCode == DELETE) comm = ""; //clear command string and close menu
   else if(keyCode == ENTER) {
     cmd = comm; 
     comm = ""; //submit and clear command string
     cmdTimer = 0; //command start time
   }
   else{
     if(key == CODED) { //save keycodes to command string, allowing for cheat code to be entered
       comm+=keyCode;
     }else {
       comm+=key; 
     }
   }
  }
}

void keyReleased() {
  if (keyCode == UP || key == 'w' || key == 'W') {
    keys[up] = false;
  }
  else if(keyCode == DOWN || key == 's' || key == 'S') {
    keys[down] = false;
  } 

  else if(keyCode == LEFT || key == 'a' || key == 'A') {
    keys[left] = false;
  } 
  else if (keyCode == RIGHT || key == 'd' || key == 'D') {
    keys[right] = false;
  }else if (keyCode == SHIFT || keyCode == CONTROL) {
   pSpeed = 5; 
  }else if(key == ' ') {
   keys[space] = false; 
  }else if(key == '`') {
   save("screenshots/screenshot_"+year()+month()+day()+"_"+hour()+minute()+second()+".png"); //take screenshot to screenshots folder
   click.play(); //camera sound
  }else if(keyCode == ENTER && keys[com]==true && cmdTimer>2 ||keyCode == DELETE) { //close command line and/or menu
   keys[com] = false; 
   comm = "";
   cmd = "";
   cmdTimer = 0; //command ended
   keys[com] = false; 
   textSize(25);
  }
}  
