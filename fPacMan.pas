unit fPacMan;

{$MODE Delphi}

interface

uses
  LCLIntf, Messages, SysUtils, Classes, Graphics, Controls, Forms,
  Dialogs, ExtCtrls, StdCtrls,{QControls, jpeg,} Buttons, lcltype, LResources;

const
  GridXSize   = 30;
  GridYSize   = 33;
  MsgRestartGame = wm_User+123;

type
  TStr4 = string[4];   // can contain a set of N,E,S,W
  TSprite=record
    SpImg   :TImage;   // picture of the ghost
    XY      :TPoint;   // grid x,y
    Sx,Sy   :double;   // smooth x,y between 0 and 1
    Dir     :char;     // N,E,S,W
    Spd     :double;
    StartPos:TPoint;
  end;

  TCell=record
    WallType  :(wtNone,wtEW,wtNS,wtNE,wtNW,wtSW,wtSE,wtNoGo);
    PillType  :(ptNone,ptPill,ptSuperPill);
    I         :integer; // used for searching the maze
  end;

  TField = array[0..GridYSize-1] of string[GridXSize];

  { TfrmPacman }

  TfrmPacman = class(TForm)
    ImgBonus1: TImage;
    ImgGhost1W: TImage;
    ImgGhost1N: TImage;
    ImgGhost1S: TImage;
    ImgGhost1: TImage;
    ImgGhost1E: TImage;
    ImgGhost2S: TImage;
    ImgGhost2: TImage;
    ImgGhost2E: TImage;
    ImgGhost3S: TImage;
    ImgGhost3: TImage;
    ImgGhost3E: TImage;
    ImgGhost4S: TImage;
    ImgGhost4: TImage;
    ImgGhost4E: TImage;
    ImgGhost4N: TImage;
    ImgGhost4W: TImage;
    imgPacman: TImage;
    ImgGhost2N: TImage;
    ImgGhost2W: TImage;
    ImgGhost3N: TImage;
    ImgGhost3W: TImage;
    img1Left: TImage;
    img2Left: TImage;
    ImgScared1: TImage;
    ImgScared2: TImage;
    lblScareTimer: TLabel;
    lblBonusTimer: TLabel;
    lbl1UP: TLabel;
    lblScore1: TLabel;
    lblHiScoreLabel: TLabel;
    lbl2UP: TLabel;
    lblHiScore: TLabel;
    lblScore2: TLabel;
    pnMain: TPanel;
    img:     TImage;
    SpriteTimer: TTimer;
    ImgBonus: TImage;
    lbBonusCnt: TLabel;
    lbGhostCnt: TLabel;
// Initializing code
    procedure FormCreate(Sender: TObject);
// Business code: Actions
    procedure OnSpriteTimer(Sender: TObject);
// User response code
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
// Debug & Test
    procedure imgMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
  private
    Pause, areScared:boolean;
    flip:Integer;
    LivesLeft:integer;
    BonusCnt :integer;
    GhostCnt :integer;
    BonusTimer:integer;
    ScareTimer:integer;
    PacMouthOpen:integer;
    PacMouthOpenDir:integer;
    PillsLeft:integer;
    PacmanDir:char;
    score,HiScore:integer;
    Sprite:array[0..5] of TSprite;
    Cells:array[0..GridXSize-1,0..GridYSize] of TCell;
    HappyGhost:array[0..5] of record X,Dir:single; end;
// Maze solving code
    function  SolveMaze     (P1,P2: TPoint): boolean;
    function  SolveMazeStep1(P1,P2: TPoint): boolean;
    function  SolveMazeStep2(P1,P2: TPoint): boolean;
    function  SolveMazeStep3(P1,P2: TPoint): boolean;
// Display code
    procedure line(x1, y1, x2, y2: integer);
    procedure DrawCells();
    procedure DrawPacman();
    procedure ShowText(aText: string);
    procedure UpdateScore();
// Initializing code
    procedure InitSprite(var aSprite: TSprite; aImg: TImage; aSpd: single);
    procedure InitSprites();
    procedure InitHappyGhost();
    procedure InitVars(aField: TField);
    procedure InitCells(aField: TField);
    procedure SetGhostScared(aScared: boolean);
// Business code: TestAndGet
    function  GetGhostDir(aXY:TPoint; aOldDir: char): char;
    function  GetBestDir(aXY:TPoint): char;
    function  GetPossibleDir(aXY:TPoint): TStr4;
    function  GetPacmanDir(aXY:TPoint; aOldDir: char): char;
    procedure GetRandomCellAndDir(var aXY:TPoint; var aDir: char);
// Business code: Actions
    procedure OnRestartMessage(var Message: TMessage); message MsgRestartGame;
    procedure EatPill(aXY: TPoint);
    procedure EatSuperPill(aXY: TPoint);
    procedure EatBonus();
    procedure EatGhost(var aGhost: TSprite);
    procedure ClearCell(aXY: TPoint);
    procedure MoveSprite(aSpriteInx:integer);
    function  DoBonusTimer(): boolean;
    procedure DoHappyGhosts();
    procedure DoScareTimer();
// Business code: Decisions
    procedure CollisionDetect(var aXY:TPoint);
    procedure RestartGame();
    procedure RestartLevel();
    procedure PacmanDies();
    procedure NextLevel();
    procedure GameOver();
// Debug & Test
    procedure DbgShow();
  end;

var
  frmPacman: TfrmPacman;

implementation


//==============================================================================
// Generic constants
//==============================================================================
// These constants define the look and feel of the game.
// They set speeds and timeouts, and the define a playing field
// To make the definition of a different playing field easier it is defined as
// an array of strings, in which each character defines specific cell-properties
// The initialization code reads this and uses it to build an array of type TCell[].
//
// The const Level1field defines a playing field.
// These are the characters used to define the habitat of the ghosts and pacman
//   'x'      : a NoGo area. It shows up empty on the screen, but ghosts, pacman
//              and bonusses cannot go there.
//   '-','|'  : a horizontal or verical wall
//   '/','\'  : a cornerwall, which one depends on surrounding cells
//   '1'..'4' : starting position of ghost 1 to 4
//   'P'      : starting position of Pacman
//   ' '      : empty space, Pacman, ghosts and bonusses can go there
//   '.'      : simple pill, Pacman, ghosts and bonusses can go there
//   'o'      : super pill,  Pacman, ghosts and bonusses can go there.
//              This also sets the "ScareTheGhosts" timer
//==============================================================================

const
   CellSize           =   16; // do not change...
   GhostSpeedScared   = 0.10; // Speed of ghosts when scared
   GhostSpeedNormal   = 0.20; // Speed of ghosts when not scared.
   PacmanSpeed        = 0.25; // Speed of Pacman
   HappyGhostSpeed    = 0.50; // Speed of happy ghosts
   BonusSpeed         = 0.04; // speed of cherries
   BonusTimeOut1      =  500; // time for cherries not visible
   BonusTimeOut2      =  300; // time for cherries visible
   ScareTimeOut       =  300; // time that the ghosts stay scared
   HuntFactor         =  0.5; // 0.0:ghosts move random, 1.0=ghosts really hunt

const
   Level1Field : TField=
     ('xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
      'x/------------\/------------\x',
      'x|............||............|x',
      'x|./--\./---\.||./---\./--\.|x',
      'x|o|xx|.|xxx|.||.|xxx|.|xx|o|x',
      'x|.\--/.\---/.\/.\---/.\--/.|x',
      'x|..........................|x',
      'x|./--\./\./------\./\./--\.|x',
      'x|.\--/.||.\--\/--/.||.\--/.|x',
      'x|......||....||....||......|x',
      'x\----\.|\--\ || /--/|./----/x',
      'xxxxxx|.|/--/ \/ \--\|.|xxxxxx',
      'xxxxxx|.||          ||.|xxxxxx',
      'xxxxxx|.|| /--  --\ ||.|xxxxxx',
      '------/.\/ | 1 3  | \/.\------',
      '       .   |  2 4 |   .       ',
      '------\./\ |      | /\./------',
      'xxxxxx|.|| \------/ ||.|xxxxxx',
      'xxxxxx|.||          ||.|xxxxxx',
      'xxxxxx|.|| /------\ ||.|xxxxxx',
      'x/----/.\/ \--\/--/ \/.\----\x',
      'x|............||............|x',
      'x|./--\./---\.||./---\./--\.|x',
      'x|.\-\|.\---/.\/.\---/.|/-/.|x',
      'x|o..||.......P........||..o|x',
      'x\-\.||./\./------\./\.||./-/x',
      'x/-/.\/.||.\--\/--/.||.\/.\-\x',
      'x|......||....||....||......|x',
      'x|./----/\--\.||./--/\----\.|x',
      'x|.\--------/.\/.\--------/.|x',
      'x|..........................|x',
      'x\--------------------------/x',
      'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx');

const
   WallSet = ['-','|','\','/'];

procedure TfrmPacman.FormCreate(Sender: TObject);
begin
  randomize();
  InitSprites();
  InitHappyGhost();
  pnmain.DoubleBuffered:=true;
  SpriteTimer.enabled:=true;
  postmessage(self.handle,MsgRestartGame,0,0); // delayed start of game
end;

//==============================================================================
//  Display code
//==============================================================================
// This code is responsible for showing pacman, ghosts, bonuses, scores on the
// screen It uses global variables and the Cells[] array to know where and what
// ShowText()      this code shows a flashing text (how surprising) in the
//                 middle of the playing field for about 3 seconds
// Line()          draws a line on img.canvas (should be a standard function!!!)
// DrawCells()     clears and draws the complete playingfield according to the
//                 cell properties in the Cell[] array. Does not draw Pacman,
//                 ghosts or flying bonusses.
// DrawPacman()    Draws an image of Pacman in sprite[0] depending on direction
// UpdateScore()   Updates the labels for lives, score, hiscore etc.

procedure TfrmPacman.ShowText(aText:string);
var n,x,y:integer;
begin       
  img.Canvas.brush.Color:=clBlack; //textbackground is black
  img.Canvas.Font.Size:=18;        //make text really big
  // position text in the middle of the field
  x:=pnMain.ClientWidth div 2-img.Canvas.TextWidth(aText) div 2;
  y:=pnMain.ClientHeight div 2-img.Canvas.TextHeight(aText) div 2 + 30;
  for n:=0 to 9 do begin // flash for 10 times 300 msec
    img.Canvas.Font.Color:=clRed;
    img.Canvas.TextOut(x,y,aText);
    img.update;  // without update the changes will not be visible
    sleep(150);  // this makes the text blink red and yellow, nicely retro...
    img.Canvas.Font.Color:=clYellow;
    img.Canvas.TextOut(x,y,aText);
    img.update;
    sleep(150);
  end;
  DrawCells(); //restore the screen behind the text
end;

procedure TfrmPacman.line(x1,y1,x2,y2:integer);
begin // should be a standard method of a canvas...
  img.Canvas.MoveTo(x1,y1); img.Canvas.LineTo(x2,y2);
end;

procedure tFrmPacman.DrawCells();
const Sze=CellSize; HSze=CellSize div 2;
var x,y,sx,sy:integer;
begin
  with img.Canvas do begin
    // clear screen to black
    Brush.Color:=clBlack;
    FillRect(img.ClientRect);
    // Draw supportGrid (helpfull during development, not needed)
    Pen.width:=1;
    Pen.Color:=$202020;
    for x:=0 to GridXSize do line(x*Sze,0,x*Sze,Sze*(GridYSize));
    for y:=0 to GridYSize do line(0,y*Sze,Sze*(GridXSize),y*Sze);
    // Draw Pills
    Pen.Color:=clWhite;
    Brush.Color:=clWhite;
    for x:=0 to GridXSize-1 do for y:=0 to GridYSize-1 do begin
      sx:=x*Sze+HSze;
      sy:=y*Sze+HSze;
      case Cells[x,y].PillType of
        ptPill      : Ellipse(sx-2,sy-2,sx+2,sy+2);
        ptSuperPill : Ellipse(sx-6,sy-6,sx+6,sy+6);
      end;
    end;
    // Draw Walls per cell
    Pen.Color:=clBlue;
    Pen.width:=sze div 4;
    for x:=0 to GridXSize-1 do for y:=0 to GridYSize-1 do begin
      sx:=x*Sze+HSze;
      sy:=y*Sze+HSze; //calculate pixel position on screen
      case Cells[x,y].WallType of
        wtEW: line(sx-hsze,sy,sx+hsze,sy);                    // left to right
        wtNS: line(sx,sy-hsze,sx,sy+hsze);                    // top to bottom
        wtSW: Arc(sx-Sze,sy,sx,sy+Sze,sx,sy+HSze,sx-HSze,sY); // bottom to left
        wtNE: Arc(sx,sy-Sze,sx+Sze,sy,sx,sy-HSze,sx+HSze,sY); // top to right
        wtSE: Arc(sx,sy,sx+Sze,sy+Sze,sx+HSze,sY,sx,sy+HSze); // bottom to right
        wtNW: Arc(sx-Sze,sy-Sze,sx,sy,sx-HSze,sY,sx,sy-HSze); // top to left
      end;
    end;
  end;
end;

procedure TfrmPacman.DrawPacman();
begin
  if PacMouthOpen>28 then PacMouthOpenDir:=-7 else // if maxopen then start closing
  if PacMouthOpen<2  then PacMouthOpenDir:= 7;     // if minopen then start opening
  inc(PacMouthOpen,PacMouthOpenDir);               // adjust mouth opening
  // directly draw into the image of sprite[0]
  with sprite[0].SpImg.Canvas do begin
    Brush.color:=clBlack;
    pen.color:=clBlack;
    pen.width:=1;
    fillrect(rect(0,0,28,30));   // clear face area to black
    Brush.color:=clYellow;       // set face color to yellow
    pen.color:=clYellow;         // pen too
    case Sprite[0].Dir of        // draw face depending on direction
      'E': Pie(1,0,28,28,0 ,14+PacMouthOpen,0 ,14-PacMouthOpen); // to the right
      'W': Pie(1,0,28,28,28,14-PacMouthOpen,28,14+PacMouthOpen); // to the left
      'N': Pie(1,0,28,28,14-PacMouthOpen,0 ,14+PacMouthOpen,0 ); // to the top
      'S': Pie(1,0,28,28,14+PacMouthOpen,28,14-PacMouthOpen,28); // to the bottom
      else Sprite[0].spImg.Picture.Assign(imgPacman.Picture);
    end;
  end;
end;

procedure TfrmPacman.UpdateScore();
begin
  if Score>HiScore then HiScore:=Score;
  // the updates are needed to see new values during code loops (ShowText)
  lblScore1.Caption   := inttostr(Score);     lblScore1.Update;
  lblHiScore.Caption := inttostr(HiScore);   lblHiScore.Update;
  //lbLives.Caption   := inttostr(LivesLeft); lbLives.Update;
  lbBonusCnt.Caption:= inttostr(BonusCnt);  lbBonusCnt.Update;
  lbGhostCnt.Caption:= inttostr(GhostCnt);  lbGhostCnt.Update;
end;

//==============================================================================
//  Initialization code
//==============================================================================
// There are several moments in the game something needs to be put in the
// beginstate.
// InitSprite()    Called by InitSprites on Create(), creates images and presets
//                 sprite variables
// InitSprites()   This code first creates and initializes all objects and
//                 variables sets their beginstate values. Called only once !!
// InitVars()      This gets some sprite properties from a TField constant
//                 and resets counters prior to a new game
// InitCells()     This copies the cell-properties from a TField constant
// SetGhostScared() sets images and speeds of the 4 ghosts depending on param.

procedure TfrmPacman.InitSprite(var aSprite:TSprite; aImg:TImage; aSpd:single);
begin
  aSprite.spImg := TImage.Create(pnMain);  // get an image instance, owned
  aSprite.SpImg.parent:=pnMain;            // and parented by pnMain
  aSprite.SpImg.Transparent:=true;         // make the black pixels transparent
  aSprite.SpImg.Width:=28;                 // make the black pixels transparent
  aSprite.SpImg.Height:=28;                // make the black pixels transparent
  aSprite.SpImg.Transparent:=true;         // make the black pixels transparent
  aSprite.spImg.Picture.Assign(aImg.Picture); // and load a bitmap image
  aSprite.dir   := '-';                    // no direction
  aSprite.Spd   := aSpd;                   // default speed
  aSprite.XY    := point(1,1);             // Just a non error generating value
  aSprite.Sx    := 0;                      // partial X in the middle of a cell
  aSprite.Sy    := 0;                      // partial Y in the middle of a cell
  aSprite.StartPos:=point(2,2);            // Just a non error generating value
end;

procedure TfrmPacman.InitSprites();
begin
  InitSprite(Sprite[0],imgPacman,PacmanSpeed);
  InitSprite(Sprite[1],ImgGhost1S,GhostSpeedNormal);
  InitSprite(Sprite[2],ImgGhost2S,GhostSpeedNormal);
  InitSprite(Sprite[3],ImgGhost3S,GhostSpeedNormal);
  InitSprite(Sprite[4],ImgGhost4S,GhostSpeedNormal);
  InitSprite(Sprite[5],ImgBonus ,BonusSpeed);
end;

procedure TfrmPacman.InitHappyGhost();
var n:integer;
begin
  HappyGhost[0].X:=250;
  HappyGhost[1].X:=ImgGhost1.left;
  HappyGhost[2].X:=ImgGhost2.left;
  HappyGhost[3].X:=ImgGhost3.left;
  HappyGhost[4].X:=ImgGhost4.left;
  HappyGhost[5].X:=480;
  for n:=1 to 4 do HappyGhost[n].Dir:=HappyGhostSpeed;
end;

procedure TfrmPacman.InitVars(aField:TField);
// Uses a TField definition to set the global variable PillCount and the initial
// positions of Pacman and the Ghosts, Also (pre)sets timers and pacman's mouth.
var x,y,n:integer;
begin
  PillsLeft:=0;
  Score    :=0;
  LivesLeft:=3;
  BonusCnt :=0;
  GhostCnt :=0;
  Pause    :=false;
  areScared:=False;
  flip     :=1;
  pacMouthopen:=5; pacMouthopenDir:=2; //startvalues for open mouth of pacman
  for x:=0 to GridXSize-1 do for y:=0 to GridYSize-1 do begin
    case aField[y,x+1] of
      '.','o': inc(PillsLeft); // normal and superpills
      'P'    : sprite[0].StartPos:=point(x,y); // starting position of PacMan
      '1'    : sprite[1].StartPos:=point(x,y); // starting position of Ghost #1
      '2'    : sprite[2].StartPos:=point(x,y); // starting position of Ghost #2
      '3'    : sprite[3].StartPos:=point(x,y); // starting position of Ghost #3
      '4'    : sprite[4].StartPos:=point(x,y); // starting position of Ghost #4
    end;
  end;
  for n:=0 to 4 do sprite[n].XY:=sprite[n].StartPos;
  ScareTimer:=0;
  BonusTimer:=0;
end;

procedure TfrmPacman.InitCells(aField:TField);
// Uses a TField definition to set properties of all cells in the Cell[] array
const wsH=['-','\','/']; // set of wall chars used in SW-NE detection
      wsV=['|','\','/']; // set of wall chars used in SE-NW detection
var   x,y:integer;
begin
  for x:=0 to GridXSize-1 do for y:=0 to GridYSize-1 do begin
    // Set values for WallType from string-field definition
    case aField[y,x+1] of
      '|': Cells[x,y].WallType:=wtNS;      // top to bottom
      '-': Cells[x,y].WallType:=wtEW;      // left to right
      '\': if (aField[y,x] in wsH) and (aField[y+1,x+1] in wsV)
           then Cells[x,y].WallType:=wtSW  // bottom to left
           else Cells[x,y].WallType:=wtNE; // top to right
      '/': if (aField[y,x+2] in wsH) and (aField[y+1,x+1] in wsV)
           then Cells[x,y].WallType:=wtSE  // bottom to right
           else Cells[x,y].WallType:=wtNW; // top to left
      'x': Cells[x,y].Walltype:=wtNoGo;    // no visible wall, but still occupied
      else Cells[x,y].WallType:=wtNone;    // no obstacle to pacman and ghosts
    end;
    // set values for PillType from string-field definition
    case aField[y,x+1] of
      '.': Cells[x,y].PillType := ptPill;  // this cell contains a Pill
      'o': Cells[x,y].PillType := ptSuperPill; // this cell a SuperPill
      else Cells[x,y].PillType := ptNone;  // walls and empty space, no points
    end;
  end;
end;

procedure TfrmPacman.SetGhostScared(aScared:boolean);
begin
  if aScared then begin // assign "scared" images and set speed to scared
    Sprite[1].spImg.Picture.Assign(ImgScared1.Picture); Sprite[1].Spd:=GhostSpeedScared;
    Sprite[2].spImg.Picture.Assign(ImgScared1.Picture); Sprite[2].Spd:=GhostSpeedScared;
    Sprite[3].spImg.Picture.Assign(ImgScared1.Picture); Sprite[3].Spd:=GhostSpeedScared;
    Sprite[4].spImg.Picture.Assign(ImgScared1.Picture); Sprite[4].Spd:=GhostSpeedScared;
    areScared:=True;
  end else begin        // assign normal ghost images and set speed to normal
    Sprite[1].spImg.Picture.Assign(ImgGhost1.Picture); Sprite[1].Spd:=GhostSpeedNormal;
    Sprite[2].spImg.Picture.Assign(ImgGhost2.Picture); Sprite[2].Spd:=GhostSpeedNormal;
    Sprite[3].spImg.Picture.Assign(ImgGhost3.Picture); Sprite[3].Spd:=GhostSpeedNormal;
    Sprite[4].spImg.Picture.Assign(ImgGhost4.Picture); Sprite[4].Spd:=GhostSpeedNormal;
    areScared:=False;
  end;
end;

//==============================================================================
//  User input code
//==============================================================================
// This is a very simple piece of code, the only function is FormKeyDown (which
// is an eventproperty of the form) which sets the direction Pacman should go.
// for now only 4 keys are valid, arrow up,down,left,right.

procedure TfrmPacman.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  case Key of
    VK_LEFT : PacmanDir := 'E';
    VK_UP	  : PacmanDir := 'N';
    VK_RIGHT: PacmanDir := 'W';
    VK_DOWN	: PacManDir := 'S';
    ord('P'): Pause:=not Pause;
  end;
end;

//==============================================================================
//  Business logic, rules of the game.
//==============================================================================
// The ghosts are aware of the position of pacman. Depending on their fear for
// him they try to get to him (Fear=-1) or to get away from him (Fear=1) or anything in
// between.
//
// Every once in a while a bonuscherry starts moving around for a some time.
// When Pacman eats the cherry the score is incremented and the cherry disappears.
// Whenever Pacman eats a small pill the score is incremented and the pill disappears
// Whenever Pacman eats a large pill the score is incremented, the pill diappears,
// and a timer is started that keeps the ghosts to a Fearlavel of 1 al long as the
// timer runs. after that the ghosts wil gradually return to fear=-1;
// When pacman eats a scared ghost the score is incremented and the ghost is sent
// back to his cave...
// When pacman eats a not so scared ghost he dies...
// In this case all ghosts are sent home, and if there are stil lives left the
// game continues with one life less...
// When Pacman runs out of lives the game is ended and a new game is started.
// If all pills are eaten the game is also ended and a new game is started.

//==============================================================================
// Business code: TestAndGet
//==============================================================================
// GetPossibleDir()
// GetGhostDir()
// GetPacmanDir()
// GetRandomCellAndDir()

function TfrmPacman.GetPossibleDir(aXY:TPoint):TStr4;
begin
  result:='';    // Start with an empty string
  if Cells[aXY.X,aXY.Y-1].WallType=wtNone then result:=result+'N'; // up is possible
  if Cells[aXY.X-1,aXY.Y].WallType=wtNone then result:=result+'E'; // left is possible
  if Cells[aXY.X,aXY.Y+1].WallType=wtNone then result:=result+'S'; // down is possible
  if Cells[aXY.X+1,aXY.Y].WallType=wtNone then result:=result+'W'; // right is possible
end;

function TfrmPacman.GetBestDir(aXY:TPoint):char;
begin
  result:='-';
  if SolveMaze(aXY,sprite[0].XY) then begin // fill the SearchIndexes cell[x,y].i
    if Cells[aXY.X,aXY.Y-1].I<-10 then result:='N'; // up    is best
    if Cells[aXY.X-1,aXY.Y].I<-10 then result:='E'; // left  is best
    if Cells[aXY.X,aXY.Y+1].I<-10 then result:='S'; // down  is best
    if Cells[aXY.X+1,aXY.Y].I<-10 then result:='W'; // right is best
  end;
end;

function TfrmPacman.GetGhostDir(aXY:TPoint; aOldDir:char):char;
var BestDir:char; D:Char;s:TStr4;
begin
  result:='-';
  s:=GetPossibleDir(aXY);
  case aOldDir of // get the direction opposite of the current direction
    'W':D:='E'; 'E':D:='W'; 'S':D:='N'; 'N':D:='S'; else D:='-';
  end;
  if (length(s)>1) then begin // more than one direction: make a choice
    BestDir:=GetBestDir(aXY);
    if (ScareTimer=0) and (BestDir<>'-') then begin//
      if random < Huntfactor then s:=BestDir; // hunt depends on factor
    end else begin
      delete(s,pos(BestDir,s),1);             // fleeing does not
    end;
  end;
  // if other than the reverse direction are possible then remove the reverse direction
  if (length(s)>1) and (pos(d,s)<>0) then delete(s,pos(d,s),1);
  if (length(s)=1) then result:=s[1];                   // only one direction possible: Go
  if (length(s)>1) then result:=s[1+random(length(s))]; // choose at random
end;

function TfrmPacman.GetPacmanDir(aXY:TPoint;aOldDir:char): char;
var s:TStr4;
begin
  s:=GetPossibleDir(aXY);
  if pos(PacmanDir,s)>0 then s:=pacmandir else
  if pos(aOldDir,s)>0   then s:=aOldDir   else s:='-';
  result:=s[1];
end;

procedure TFrmPacman.GetRandomCellAndDir(var aXY:TPoint; var aDir:char);
begin
  repeat
    aXY:=point(1+random(GridXSize-3),random(GridYSize-3));
  until (Cells[aXY.x,aXY.y].WallType=wtnone);
  aDir:=GetGhostDir(aXY,'-');
end;

//==============================================================================
// Business code: Actions
//==============================================================================
// OnRestartMessage()
// EatPill()
// EatSuperPill()
// EatBonus()
// EatGhost()
// ClearCell()
// MoveSprite()
// DoBonusTimer()
// DoScareTimer()
// OnSpriteTimer()

procedure TfrmPacman.OnRestartMessage(var Message: TMessage);
begin
  RestartGame(); // start game after VCL is ready drawing the screen
end;

procedure TfrmPacman.EatPill(aXY:TPoint);
begin
  inc(Score, 1);
  ClearCell(aXY);
  dec(PillsLeft);
  UpdateScore();
  if PillsLeft=0 then NextLevel();
end;

procedure TfrmPacman.EatSuperPill(aXY:TPoint);
begin
  ClearCell(aXY);
  ScareTimer:=ScareTimeOut; // Make 'm scared for a while...
  inc(Score,10);
  UpdateScore();
  dec(PillsLeft); if PillsLeft=0 then NextLevel();
end;

procedure TfrmPacman.EatBonus();
begin
  BonusTimer:=0;  // remove cherry
  inc(Score,50);
  inc(BonusCnt);
  UpdateScore();  // write scores to screen
end;

procedure TfrmPacman.EatGhost(var aGhost:TSprite);
begin
  aGhost.XY:=aGhost.StartPos; // send ghost home
  inc(Score,20);
  inc(GhostCnt);
  UpdateScore();              // write scores to screen
end;

procedure tFrmPacman.ClearCell(aXY:TPoint);
var sx,sy:integer;
begin
  cells[aXY.X,aXY.Y].PillType:=ptNone; // clear cell in Cell[] array
  img.canvas.Brush.Color:=clBlack;     // also clear this part of the canvas
  sx:=aXY.x*CellSize;
  sy:=aXY.y*CellSize;
  img.canvas.fillrect(rect(sx+1,sy+1,sx+cellsize,sy+cellsize));
end;

procedure TFrmPacman.MoveSprite(aSpriteInx:integer);
var
    oXY:TPoint;
    tmpImage: TImage;
begin
  with Sprite[aSpriteInx] do begin
    // change position depending on direction
    oXY:=XY;
    case Dir of
      'N': begin Sy:=Sy-Spd; if Sy<=-1 then begin dec(XY.y); Sy:=Sy+1; end; end;
      'E': begin Sx:=Sx-Spd; if Sx<=-1 then begin dec(XY.x); Sx:=Sx+1; end; end;
      'S': begin Sy:=Sy+Spd; if Sy>= 1 then begin inc(XY.y); Sy:=Sy-1; end; end;
      'W': begin Sx:=Sx+Spd; if Sx>= 1 then begin inc(XY.x); Sx:=Sx-1; end; end;
      else begin oXY:=point(0,0); Sx:=0;Sy:=0; end;
    end;
    //if cell changed then choose new direction depending on wall limitations
    if (XY.x<>oXY.x) or (XY.y<>oXY.y) then begin
      if   aSpriteInx=0
      then dir:=GetPacmanDir(XY,dir)
      else
      begin
        dir:=GetGhostDir (XY,dir);
        if (aSpriteInx < 5) and (not areScared) then
        begin
          tmpImage := FindComponent('ImgGhost'+IntToStr(aSpriteInx)+dir) as TImage;
          Sprite[aSpriteInx].spImg.Picture.Assign(tmpImage.Picture);
        end;
      end;
      if dir in ['E','W'] then sy:=0 else sx:=0; //correct partial displacements
      if aSpriteInx=0 then CollisionDetect(XY);  //only for The Man himself...
    end;
    // if position goes offgrid then reenter on the other side of the screen
    if XY.x>GridXSize-3 then XY.x:=2; if XY.x<2 then XY.x:=GridXSize-3;
    if XY.y>GridYSize-3 then XY.y:=2; if XY.y<2 then XY.y:=GridYSize-3;
    // set sprite image position according to new Cx:Sx,Cy,Sy
    SpImg.Left := round((XY.x+Sx+0.5)*CellSize-SpImg.picture.Width/2 );
    SPImg.Top  := round((XY.y+Sy+0.5)*CellSize-SpImg.picture.Height/2);
  end;
end;

function TfrmPacman.DoBonusTimer():boolean;
begin
  if BonusTimer>=0 then begin // bonustimer is positive: cherry is onscreen
    dec(BonusTimer);
    if BonusTimer<=0 then begin // if decrement makes it negative then
      sprite[5].SpImg.visible:=false; // remove cherry from screen, and
      BonusTimer:=-BonusTimeOut1-random(BonusTimeOut1); // set a negative timeout
    end;
  end else begin   // if bonus timer is negative then cherry is not onscreen
    inc(BonusTimer);
    if BonusTimer>=0 then begin        // when increment makes it positive then
      sprite[5].SpImg.visible:=true;   // make cherry visible,
      sprite[5].Sx:=0; sprite[5].Sy:=0;// set partial position to zero, and
      GetRandomCellAndDir(Sprite[5].XY,Sprite[5].Dir);// choose a random position
      BonusTimer:=+BonusTimeOut2+random(BonusTimeOut2); // Set a positive timeout
    end;
  end;
  // update a custom made progressbar on the screen
  if BonusTimer>0 then begin
    pnbonusbarInner.Color:=clLime;
    pnBonusBarInner.Width:=bonustimer*pnBonusBarOuter.ClientWidth div (2*BonusTimeOut2);
  end else begin
    pnbonusbarInner.Color:=clRed;
    pnBonusBarInner.Width:=-bonustimer*pnBonusBarOuter.ClientWidth div (2*BonusTimeOut1);
  end;
  result:=BonusTimer>0;
end;

procedure TfrmPacman.DoScareTimer();
begin
  // just after superpill is eaten the caretimer is set to ScareTimeOut
  if ScareTimer>=ScareTimeOut then SetGhostScared(true); //frighten them !!
  if ScareTimer>0 then begin
    dec(ScareTimer);
    if ScareTimer <= 100 then
    begin
      if ScareTimer MOD 10 = 0 then
      begin
        flip:=flip*(-1);
        if flip > 0 then
        begin
          Sprite[1].spImg.Picture.Assign(ImgScared2.Picture);
          Sprite[2].spImg.Picture.Assign(ImgScared2.Picture);
          Sprite[3].spImg.Picture.Assign(ImgScared2.Picture);
          Sprite[4].spImg.Picture.Assign(ImgScared2.Picture);
        end
        else
        begin
          Sprite[1].spImg.Picture.Assign(ImgScared1.Picture);
          Sprite[2].spImg.Picture.Assign(ImgScared1.Picture);
          Sprite[3].spImg.Picture.Assign(ImgScared1.Picture);
          Sprite[4].spImg.Picture.Assign(ImgScared1.Picture);
        end;
      end;
    end;
    // if scaretimer becomes zero then scare time is over: return to normal
    if ScareTimer=0 then SetGhostScared(false); // fun is over...
  end;
  //lblScareTimer.Caption := ' Scare Timer: ' + IntToStr(ScareTimer);// for debug only
end;

procedure TfrmPacman.DoHappyGhosts();
var n:integer;
begin
  for n:=1 to 4 do
    if HappyGhost[n].X<=HappyGhost[n-1].X+28 then
      HappyGhost[n].Dir := (1+random)*HappyGhostSpeed;
  for n:=4 downto 1 do
    if HappyGhost[n].x>=HappyGhost[n+1].X-28 then
      HappyGhost[n].Dir := -(1+random)*HappyGhostSpeed;
  for n:=1 to 4 do
    HappyGhost[n].x:=HappyGhost[n].x+HappyGhost[n].dir;
  ImgGhost1.Left := round(HappyGhost[1].x);
  ImgGhost2.Left := round(HappyGhost[2].x);
  ImgGhost3.Left := round(HappyGhost[3].x);
  ImgGhost4.Left := round(HappyGhost[4].x);
end;

procedure TfrmPacman.OnSpriteTimer(Sender: TObject);
var n:integer;
begin
  if Pause=false then begin
    for n:=0 to 4 do MoveSprite(n);       // for 'Pacman' and each 'Ghost'
    if DoBonusTimer() then MoveSprite(5); // update bonustimer plus cherry
    DoScareTimer();  // update the timer that controls scaring of the ghosts
    DrawPacman();    // the images have moved, update the pacmanface
  end;
  DoHappyGhosts();
end;

//==============================================================================
// Business code: Decisions
//==============================================================================
// CollisionDetect()
// RestartGame()
// RestartLevel()
// PacmanDies()
// NextLevel()
// GameOver()

procedure tFrmPacman.CollisionDetect(var aXY:TPoint);
var n,ix,dX,dY:integer;
begin
  case cells[aXY.X,aXY.Y].PillType of
    ptPill      :EatPill(aXY);
    ptSuperPill :EatSuperPill(aXY);
  end;
  ix:=0; for n:=1 to 5 do begin
    dX:=sprite[n].XY.x-aXY.x;
    dY:=sprite[n].XY.y-aXY.y;
    if (abs(dX)<=1) and (abs(dY)<=1) then ix:=n;
  end;
  if (ix=5) and (BonusTimer>0) then EatBonus();
  if ix in [1..4] then begin
    if ScareTimer>0 then EatGhost(sprite[ix]) else PacmanDies();
  end;
end;

procedure TfrmPacman.RestartGame();
begin
  InitVars(Level1Field);
  InitCells(Level1Field);
  RestartLevel();
end;

procedure TfrmPacman.ReStartLevel();
var n:integer;
begin
  DrawCells();
  for n:=0 to 4 do Sprite[n].XY:=Sprite[n].StartPos;
  UpdateScore();
  SetGhostScared(false);
  for n:=0 to 4 do MoveSprite(n); // for 'Pacman' and each 'Ghost'
  PacmanDir:='-';
  DrawPacman();                   // the images have moved, set the pacmanface
  ShowText('READY!');
  PacmanDir:='-';
end;

procedure TfrmPacman.PacmanDies();
begin
//exit;
  dec(LivesLeft);
  UpdateScore();
  ShowText('YOU DIE !!!');
  if LivesLeft=0 then GameOver() else ReStartLevel();
end;

procedure TfrmPacman.NextLevel();
begin
  ShowText('YOU WIN !!!');
  RestartGame();
end;

procedure TfrmPacman.GameOver();
begin
  ShowText('YOU LOOSE !!!');
  RestartGame();
end;

//==============================================================================
// Maze solving
//==============================================================================
// Solving a maze is implemented here as a 3 step process.
// Step 1:
//   All accessible maze cells get an searchindex of 0, all blocked cells
//   (f.i. Walls) get an index of -1.
// Step 2:
//   Two arrays are used to keep track of a set of cells that are tested
//   This step begins with adding the first point to the primary array.
//   This now contains exactly one cell. Then a loop starts: for each cell in
//   the primary array the 4 surrounding cells are tested (left,right,up down)
//   If the index of such a cell is 0 then the cell is free and it is added to
//   a secondary array of cell coordinates. The searchindex of the cell is set
//   to a value that is one higher than the searchindex of original cell.
//   If the neighbour cells of all cells in the primary array are tested then
//   the secondary array is copied to the primary array and the secondary array
//   is cleared.
//   There are 2 reasons to end this loop:
//   1: The cell that was searched for is found
//   2: There are no more cells with a searchindex of 0, secondary array is empty
//   When this is all done the cells have a search index that increments as the
//   cell is further away from the originating point. Not all cells are tested.
//   When the loop finds the target in say 10 steps the testing stops, so no cell
//   will get an index higher than 10.
//   Imagine an octopus with growing tentacles that stops when the prey is found
// Step 3:
//   Now that the target is found we have to find "the tentacle that leads back
//   to the octopus", the shortest way back to the originating point.
//   This is done by starting at the endpoint, and looking in the surrounding
//   cells for a valid searchindex that is smSprite[aSpriteInx].spImg.Picture.Assign(tmpImage.Picture);aller  than the cells own searchindex.
//   Move the cellpointer to the adjacing cell with a smaller index and eventually
//   you get back to the source.
//   Imagine a river valley in which a lot of streams go down to the middle. Just
//   follow gravity and you will end up in the center.
//   On the way back the cells are marked, and that way you will have a set of
//   cells that give you the shortest route form A to B.
//
// For debugging the searchindexes are set to 10 and higher for the tested cells
// on routes without result, and -10 and lower for the tested cells that are part
// of the shortest route. SearchIndex = 10 or -10 is the startingpoint.
// Blocked cells are -1, Untested cells are 0.
// Cells with an index of -10 or less are the solution.
//
// For this game we are only interested in the first direction decision of a
// Ghost, so after step 1 to 3 we only look which cell in the adjacent cells of
// a Ghost is in the path, and send the Ghost that way (or opposite when it is
// scared).

function TfrmPacman.SolveMaze(P1,P2:TPoint):boolean;
begin  // 3 step maze solving algorithm
                 result := SolveMazeStep1(P1,P2);  // step1
  if result then result := SolveMazeStep2(P1,P2);  // step2
  if result then result := SolveMazeStep3(P1,P2);  // step3
end;

function TfrmPacman.SolveMazeStep1(P1,P2:TPoint):boolean;
var x,y:integer;
begin
  for x:=0 to GridXSize-1 do for y:=0 to GridYSize-1 do begin
    if   Cells[x,y].WallType=wtNone
    then Cells[x,y].I:=0   // these cells can be part of a route
    else Cells[x,y].I:=-1; // these cells can not...
  end;
  // no search is usefull if P1 or P1 is not a valid cell...
  result:= (cells[P1.x ,P1.y].I=0) and (cells[P2.x,P2.y].I=0)
end;

// In the procedure below a fixed size is used for SArr1 and SArr2.
// Of course it is much better to use a dynamic array that is never too small
// I tested the maximum number of alternative routes in this maze is 17, and the
// maximum number of searchloops is 54.
// To keep code as simple as possible the arraysizes are set to 64 (17 needed).
function TfrmPacman.SolveMazeStep2(P1, P2: TPoint):boolean;
var SArr1,SArr2:array[0..63] of tpoint;
    SArr1Cnt,SArr2Cnt:integer;
    SI:integer; n:integer;
  procedure AddLS2(x,y:integer);
  begin
    if (x<0) or (x>=GridXSize) then exit;       // index offgrid: do nothing
    if (y<0) or (y>=GridYSize) then exit;       // index offgrid: do nothing
    if cells[x,y].i<>0         then exit;       // cell is blocked: do nothing
    cells[x,y].i:=SI;                           // cell is usable: give index
    SArr2[SArr2Cnt]:=point(x,y); inc(SArr2Cnt); // add cell to SArr2 for next run
    if (x=P2.x) and (y=P2.y) then Result:=true; // if endpoint is found then stop
  end;
begin
  SI:=10; Result:=false;    // start at 10 to have some special numbers to spare
  cells[p1.x,p1.y].i:=SI;   // for debugging, set the searchindex of first cell
  SArr1Cnt:=1; SArr1[0]:=P1;// prepare primary array with one (the first) cell
  repeat                    // now start searching for PacMan !!
    inc(SI);                // increment search index
    SArr2Cnt:=0;            // clear secondary array
    for n:=0 to SArr1Cnt-1 do begin // for all points in primary array do
      AddLS2(SArr1[n].x+1,SArr1[n].y  );// Test and maybe add cell to the right
      AddLS2(SArr1[n].x  ,SArr1[n].y+1);// Test and maybe add cell below
      AddLS2(SArr1[n].x-1,SArr1[n].y  );// Test and maybe add cell to the left
      AddLS2(SArr1[n].x  ,SArr1[n].y-1);// Test and maybe add cell above
    end;
    //now copy alle new searchpoints in SArr2 to sArr1, and set the number of points
    for n:=0 to SArr2Cnt-1 do SArr1[n]:=SArr2[n]; SArr1Cnt:=SArr2Cnt;
  until Result or (SArr2Cnt=0); // repeat until pacman is found or all cells tested
end;

function TfrmPacman.SolveMazeStep3(P1,P2: TPoint):boolean;
var Rdy:boolean; dP:TPoint; I:integer;
  procedure Check(x,y:integer);
  var It:integer;
  begin
    if (x<0) or (x>=GridXSize) then exit;   // index offgrid: do nothing
    if (y<0) or (y>=GridYSize) then exit;   // index offgrid: do nothing
    It:=cells[x,y].I;               // make a long name short...
    if (It>0) and (It<I) then begin // if index is smaller than the last but >0
      I:=It;                        // then make I the smaller index
      dP:=point(x,y);               // and make the next cell the tested cell
    end;
  end;
begin
  repeat
    I:=cells[P2.x,P2.y].i;          // inx of current cell (P)
    dP:=P2;                         // make next p equal to current cell
    Check(P2.x+1,P2.y  );           // test right
    Check(P2.x-1,P2.y  );           // test left
    Check(P2.x  ,P2.y+1);           // test bottom
    Check(P2.x  ,P2.y-1);           // test top
    Rdy:=(dP.x=P2.x)and(dP.y=P2.y); // if dP still equal to P than search is over
    cells[p2.x,p2.y].i := -cells[p2.x,p2.y].i;// mark this cell as returnpath
    P2:=dP;                         // move current cell to the next one
  until Rdy;
  result:=(P2.x=P1.x)and(P2.y=P1.y);// what can possibly go wrong???
end;

//==============================================================================
// Debug & Test
//==============================================================================
// this code makes the searchindexes visible in the field. It is used for
// educational and debugging purposes only.

procedure TfrmPacman.imgMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var P:TPoint; 
begin
  P.x:=x div CellSize; // convert mouseposition to cell address in G
  P.y:=y div CellSize;
  DrawCells();
  SolveMaze(P,Sprite[0].XY);  // from mouseclick position to PacMan
  DbgShow();
end;

procedure TfrmPacman.DbgShow();
var x,y:integer;
begin
  img.canvas.brush.color:=clblack;
  img.canvas.font.color:=clyellow;
  img.canvas.font.size:=5;
  for x:=0 to GridXSize-1 do for y:=0 to GridYSize-1 do begin
    if Cells[x,y].I>=10 then begin
      img.canvas.font.color:=clYellow;
      img.canvas.TextOut(x*CellSize,y*CellSize,inttostr(Cells[x,y].I));
    end;
    if Cells[x,y].I<=-10 then begin
      img.canvas.font.color:=clRed;
      img.canvas.TextOut(x*CellSize,y*CellSize,inttostr(-Cells[x,y].I));
    end;
  end;
end;

initialization
  {$i fPacMan.lrs}
  {$i fPacMan.lrs}

end.








