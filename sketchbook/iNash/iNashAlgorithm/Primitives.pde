State sample()
{
  State s = new State(
    new PVector(random(map.width), random(map.height)),
    new PVector(random(2)-1, random(2)-1)
    );
  return s;
}
float pathCost(Path path, State goal)
{
  float cost = 0;
  for(Edge e : path.edges)
  {
    cost += e.cost();
  }
  return cost;
}
boolean collisionFreePath(Path path, Path[] otherRobotPaths)
{
  // Check that the current path doesn't overlap with other robot paths
  
  return true;
}
boolean meetsPathConstraints(Path path)
{
  //TODO
  return true;
}
Edge[] findParentEdges(State vertex, Edge[] edges)
{
  Edge[] parents = new Edge[0];
  for(Edge e : edges)
  {
    if(vertex.position.x == e.v2.position.x && vertex.position.y == e.v2.position.y && vertex.rotation.x == e.v2.rotation.x && vertex.rotation.y == e.v2.rotation.y)
    {
        parents = (Edge[]) append(parents, e);
    }
  }
  return parents;
}
Path[] goalPaths(State x, Edge[] edges, Path[] paths, int index)
{
  Edge[] parents = findParentEdges(x, edges);
  if(paths.length == 0)
  {
    DEBOUT("Starting new path tree");
    paths = new Path[1];
  }
  if(parents.length == 0)
  {
    //DEBOUT("Index = "+str(index)+"; Paths length: "+str(paths.length));
    paths[index].pushByState(x);
    return paths;
  }
  for(int i=0; i<parents.length; i++)
  {
    DEBOUT(x.toString()+" has "+str(parents.length)+" parents");
    if(i==0)
    {
      paths[index].pushByEdge(parents[i]);
      paths = goalPaths(parents[i].v1, edges, paths, index);
    }
    else
    {
      //DEBOUT("Branching goal path");
      paths = (Path[]) append(paths, paths[index]);
      paths[paths.length-1].pushByEdge(parents[i]);
      paths = goalPaths(parents[i].v1, edges, paths, paths.length-1);
    }
  }
  return paths;
}
boolean inGoal(State s)
{
  if(PVector.dist(s.position,GOALS[CURRENT_ROBOT].position) <=  GOAL_RADII[CURRENT_ROBOT]/2)
    return true;
  else
    return false;
}
State[] findGoalVertices(State[] vertices)
{
  State[] result = new State[0];
  for(State v : vertices)
  {
    if(inGoal(v))
      result = (State[]) append(result, v);
  }
  DEBOUT(str(CURRENT_ROBOT)+") has "+str(result.length)+" goal vertices");
  return result;
}
Path[] pathGeneration(Graph graph)
{
  //Depth-first search
  State[] goalVerts = findGoalVertices(graph.vertices);
  Path[] pathSet = new Path[0];
  Path[] paths = new Path[0];
  for(State g : goalVerts)
  {
    paths = new Path[1];
    paths[0] = new Path(g);
    paths = goalPaths(g, graph.edges, paths, 0);
    pathSet = (Path[]) concat(pathSet, paths); 
  }
  DEBOUT("# of paths: "+str(paths.length));
  return paths;
  /*
  State[] leaves = traceFromState(graph.vertices[0], graph.edges);
  for(State leaf : leaves)
  {
    // Draw the leaf
    fill(ROBOT_COLORS[CURRENT_ROBOT]);
    leaf.drawState();
    
    if(paths == null)
    {
      paths = new Path[1];
      paths[0] = generatePath(leaf, graph.edges);
    }
    else
    {
      paths = (Path[]) append(paths, generatePath(leaf, graph.edges));
    }
  }
  for(Path p : paths)
  {
    if(p != null)
    {
      fill(color(random(255),random(255),random(255)));
      p.drawPath();
    }
    else
    {
      print("Path is null");
    }
  }
  return paths;
  */
}
State nearest(State[] vertices, State xrand)
{
  State nearestState = vertices[0];
  for(State vertex : vertices)
  {
    if(PVector.dist(vertex.position, xrand.position) < PVector.dist(nearestState.position, xrand.position))
      nearestState = vertex;
  }
  return nearestState;
}
State steer(State x, State y)
{
  float dt = 10;
  State[] outcomes = dynamics( x, y, dt);
  if(outcomes.length == 0)
    return null;
  State optimalY = outcomes[0];
  for(State outcome : outcomes)
  {
    if(PVector.dist(outcome.position, y.position) < PVector.dist(optimalY.position, y.position))
    {
      optimalY = outcome;
    }
  }
  return optimalY;
}
State[] dynamics(State x, State u, float dt)
{
  //Dubin's car
  int resultNum = 10;
  State[] results = new State[0];
  float velocity = 1;
  float theta = x.rotation.heading();
  float turnRadius = PI/8;
  for(int i=0; i<resultNum; i++)
  {
    float temp = theta - turnRadius + (i*turnRadius*2/resultNum);
    State tempState = new State(x.position.get(), x.rotation.get());
    tempState.rotation = PVector.fromAngle(temp);
    tempState.rotation.setMag(velocity*dt);
    tempState.position.add(tempState.rotation);
    if(obstacleFree(x, tempState))
      results = (State[]) append(results, tempState);
  }
  //TODO apply dynamics to steer()
  /*PVector direction = PVector.sub(u.position, x.position);
  direction.normalize();
  direction.setMag(dt);
  State steered = new State();
  steered.position = PVector.add(x.position, direction);
  State[] result = {steered};*/
  return results;
}
State[] nearVertices(State[] vertices, State x, float r)
{
  State[] result = new State[0];
  for(State s : vertices)
  {
    if(PVector.dist(s.position, x.position) <= r)
    {
        result = (State[]) append(result, s);
    }
  }
  return result;
}
boolean obstacleFree(State v1, State v2)
{
  if(v2 == null || v1 == null)
    return false;
  if(int(v2.position.y)*width+int(v2.position.x) >= width*height)
    return false;
  if(int(v2.position.y)*width+int(v2.position.x) < 0)
    return false;
  loadPixels();
  //TODO check the path between the points
  if(map.pixels[int(v2.position.y)*width+int(v2.position.x)] == color(0,0,0))
    return false;
  return true;
}
