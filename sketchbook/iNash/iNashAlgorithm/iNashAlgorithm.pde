final int N = 1;
final int K = 200000;
int frame = 0;
PImage map;
State[][] VERTICES;  //[robot][vertex#]
Edge[][] EDGES;  //[robot][edge#]
Graph[] GRAPHS;  //[robot]
State[] GOALS;  //[robot]
int[] FINISHED_ROBOTS;  //[finish_order]
Path[] BEST_PATHS;  // Previous best paths [robot]
Path[] _BEST_PATHS;  // Current best paths [robot]
Path[][] OTHER_ROBOT_PATHS;  //[robot][path#]
int k;
int CURRENT_ROBOT; // For goal checking
color[] ROBOT_COLORS;
float[] GOAL_RADII;

float freeArea()
{
  int count = 0;
  loadPixels();
  for (int i=0; i<map.width*map.height; i++)
  {
    if (map.pixels[i] == color(255, 255, 255))
      count++;
  }
  return count;
}
int DIMENSION = 2;
float GAMMA;
float ETA = 4;
float dt = 0.5;

float GOAL_COST = MIN_FLOAT;
// For Feedback Loop
Action[] ACTIONS;
Path[] FEEDBACK_PATHS;

boolean DEBUG = true;
boolean DRAW_GRAPH = false;
boolean DRAW_INFO = false;
boolean DRAW_STATES = false;
boolean QUITTING = false;

DynamicsType DYNAMICS_TYPE = DynamicsType.DOUBLE_INTEGRATOR;

PrintWriter[] FEEDBACK_COST_OUTPUT = new PrintWriter[N];
PrintWriter[] PATH_LENGTH_OUTPUT = new PrintWriter[N];
PrintWriter[] PATH_COST_OUTPUT = new PrintWriter[N];
PrintWriter[] VERTS_EDGES_OUTPUT = new PrintWriter[N];
PrintWriter[] VERT_COSTS_OUTPUT = new PrintWriter[N];

// Dynamics
int acceleration_range = 1;
int dir_range = 8;
float ACTION_MAG = 20;

String timestamp;

void setup()
{
  noSmooth();
  timestamp = year()+"-"+month()+"-"+day()+"-"+hour()+"-"+minute()+"-"+second();
  // Setup data logging
  for (int i=0; i<N; i++)
  {
    FEEDBACK_COST_OUTPUT[i] = createWriter("output_"+timestamp+"/"+str(i)+"_feedback_cost.log");
    PATH_COST_OUTPUT[i] = createWriter("output_"+timestamp+"/"+str(i)+"_path_cost.log");
    PATH_LENGTH_OUTPUT[i] = createWriter("output_"+timestamp+"/"+str(i)+"_path_length.log");
    VERTS_EDGES_OUTPUT[i] = createWriter("output_"+timestamp+"/"+str(i)+"_verts_edges.log");
    VERT_COSTS_OUTPUT[i] = createWriter("output_"+timestamp+"/"+str(i)+"_vert_costs.log");
  }

  frameRate(100000);
  map = loadImage("map1.png");
  size(map.width, map.height);
  background(255);
  GAMMA = 2*(1+1/DIMENSION)*(freeArea()/1);

  ACTIONS = new Action[0];
  for (int i=0; i<50; i++)
  {
    Action temp = new Action();
    temp = temp.sample();
    ACTIONS = (Action[]) append(ACTIONS,temp.sample()/*new Action()*/);
  }
  
  VERTICES = new State[N][1];
  EDGES = new Edge[N][1];
  GRAPHS = new Graph[N];
  GOALS = new State[N];
  FINISHED_ROBOTS = new int[0];
  BEST_PATHS = new Path[N];
  _BEST_PATHS = new Path[N];
  FEEDBACK_PATHS = new Path[N];
  OTHER_ROBOT_PATHS = new Path[N][N];
  k=0;
  CURRENT_ROBOT = 0; 
  ROBOT_COLORS = new color[N];
  GOAL_RADII = new float[N];
  for (int i=0; i<N; i++)
  {
    VERTICES[i][0] = new State();
    EDGES[i] = new Edge[0];
    GRAPHS[i] = new Graph(VERTICES[i], EDGES[i]);
    GOALS[i] = new State();
    GOALS[i].cost = GOAL_COST;
    BEST_PATHS[i] = new Path();
    _BEST_PATHS[i] = new Path();
    ROBOT_COLORS[i] = color(random(150), random(150), random(150), 150);
    GOAL_RADII[i] = 5;
    FEEDBACK_PATHS[i] = new Path();
  }
  k=1;
}

void draw()
{
  DEBOUT("");
  DEBOUT("Iteration: "+str(k));
  background(map);

  // REGION iNash Algorithm + Feedback loop
  if (!QUITTING)
  {
    Action temp = new Action();
    ACTIONS = (Action[]) append(ACTIONS, temp.sample());
    iNash();
    DEBOUT("There are "+str(nearVertices(GRAPHS[0].vertices, GOALS[0], GOAL_RADII[0]).length)+" goal vertices");
    feedbackLoop();
  }

  // Draw robots
  for (int i=0; i<N; i++)
  {
    fill(255, 0, 0);
    stroke(255, 0, 0);
    ellipse(GOALS[i].position.x, GOALS[i].position.y, GOAL_RADII[i]*2, GOAL_RADII[i]*2);
    fill(ROBOT_COLORS[i]);
    stroke(ROBOT_COLORS[i]);
    //ellipse(VERTICES[i][0].position.x, VERTICES[i][0].position.y, 6, 6);
    stroke(0);
    strokeWeight(1);
    /*line(VERTICES[i][0].position.x, VERTICES[i][0].position.y, 
     PVector.add(VERTICES[i][0].position, 
     PVector.mult(VERTICES[i][0].rotation, 6)).x, 
     PVector.add(VERTICES[i][0].position, 
     PVector.mult(VERTICES[i][0].rotation, 6)).y);*/
    strokeWeight(1);

    // draw the graph
    if (GRAPHS[i].edges.length != 0 && DRAW_GRAPH)
    {
      stroke(ROBOT_COLORS[i]);
      GRAPHS[i].drawGraph();
    }
    if (DRAW_STATES)
    {
      for (State s : VERTICES[i])
      {
        //DEBOUT(str(s.cost));
        fill(2550*s.cost/GOAL_COST, 0, 0, 100);
        stroke(2550*s.cost/GOAL_COST, 0, 0, 100);
        s.drawState();
      }
    }
    strokeWeight(1);
    stroke(color((complement(ROBOT_COLORS[i]) & 0xffffff) | (200 << 24)));
    BEST_PATHS[i].drawPath();
    stroke(color((complement(ROBOT_COLORS[i]) & 0xffffff) | (200 << 24)));
    FEEDBACK_PATHS[i].drawPath();
    strokeWeight(1);
  }
  // Draw information
  if (DRAW_INFO)
  {
    fill(255, 255, 255, 190);
    stroke(255, 255, 255, 210);
    rect(0, 0, 225, 50+75*N);
  }
  for (int i=0; i<N; i++)
  {
    if (k % 20 == 0)
    {
      FEEDBACK_COST_OUTPUT[i].println(str(k)+", "+FEEDBACK_PATHS[i].cost());
      PATH_COST_OUTPUT[i].println(str(k)+", "+BEST_PATHS[i].cost());
      PATH_LENGTH_OUTPUT[i].println(str(k)+", "+BEST_PATHS[i].edges.length);
      VERTS_EDGES_OUTPUT[i].println(str(k)+", "+"Verts:"+str(VERTICES[i].length)+" Edges:"+str(EDGES[i].length));
      for(State s : GRAPHS[i].vertices)
      {
        VERT_COSTS_OUTPUT[i].println(str(k)+", "+str(s.cost));
      }
    }
    if (DRAW_INFO)
    {
      fill(ROBOT_COLORS[i]);
      stroke(ROBOT_COLORS[i]);
      text(str(i)+") location: "+VERTICES[i][0].toString(), 0, 45+75*i);
      text("    vertices: "+str(VERTICES[i].length), 0, 60+75*i);
      text("    edges: "+str(VERTICES[i].length), 0, 75+75*i);
      text("    path length: "+str(BEST_PATHS[i].vertices.length), 0, 90+75*i);
      text("    goal: "+GOALS[i].toString(), 0, 105+75*i);
      //VERTICES[i][0].drawState();
      text("("+str(i)+")", VERTICES[i][0].position.x+5, VERTICES[i][0].position.y);
      fill(0, 255, 0);
      stroke(0, 255, 0);
      text("Iteration: "+str(frame), 0, 15);
      text("Finished robots: "+str(FINISHED_ROBOTS.length), 200, 15);
    }
  }
  //text("'D':debug, 'S':states, 'G':graph, 'I':info, 'P':pause", 0, 30);
  frame++;
}

