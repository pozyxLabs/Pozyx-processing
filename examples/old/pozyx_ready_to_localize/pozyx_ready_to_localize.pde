import org.gwoptics.graphics.graph2D.Graph2D;
import org.gwoptics.graphics.graph2D.traces.*;
import org.gwoptics.graphics.graph2D.backgrounds.*;
import org.gwoptics.graphics.GWColour;
import processing.serial.*;
import java.lang.Math.*;



String portName = "COM30";      // change this to your COM port 
int NUM_ANCHORS = 4;

/////////////////////////////////////////////////////////////
//////////////////////  variables //////////////////////////
/////////////////////////////////////////////////////////////

Graph2D g_range, g_rss;
Graph2D map;
Serial  myPort;
int     lf = 10;       //ASCII linefeed
String  inString;      //String for testing serial communication

// ANCHOR COLORS
int[] rgb_color = {0, 0, 255, 0, 160, 122, 0, 255, 0, 255};

int positionHistory = 50;

ArrayList<rangeData> range_data;
ArrayList<rangeData> rss_data;

positionDataHistory position_data;

int [][]anchors = new int [4][0];
String []anchor_ids =  new String[0];

// some variables for plotting the map
int plane_x = 650;
int plane_y = 40;
int plane_height = 600;
int plane_width = 700;  

float pixel_per_mm = 0.05;

int border = 500;
int thick_mark = 500;

class positionDataHistory{
    private int[] pos_x = new int [positionHistory];
    private int[] pos_y = new int [positionHistory];
    private int[] pos_z = new int [positionHistory];
    
    private int err_x = 0;
    private int err_y = 0;
    private int err_z = 0;
    private int err_xy = 0;
    private int err_xz = 0;
    private int err_yz = 0;

    public void addPosition(int x, int y, int z){
      System.arraycopy(pos_x, 0, pos_x, 1, positionHistory - 1);
      System.arraycopy(pos_y, 0, pos_y, 1, positionHistory - 1);
      System.arraycopy(pos_z, 0, pos_z, 1, positionHistory - 1);
      
      pos_x[0] = x;
      pos_y[0] = y;
      pos_z[0] = z;
    }
    
    public void addError(int x, int y, int z, int xy, int xz, int yz){
      err_x = x;
      err_y = y;
      err_z = z;
      err_xy = xy;
      err_xz = xz;
      err_yz = yz;
    }
    
    public int[] getCurPosition(){
      int[] position ={pos_x[0], pos_y[0], pos_z[0]};
      return position;
    }    
}


class rangeData implements ILine2DEquation{
    private double curVal = 0;
    private int nCount = 0;
    private float range_avg = 0;
    private float pwrSumAvg = 0;
    private float range_std = 0;
  
    public float get_range_avg(){return range_avg;}
    public float get_range_std(){return range_std;}
    public void reset_statistics(){
      nCount = 0;
      range_avg = 0;
      pwrSumAvg = 0;
      range_std = 0;
    }
    
    public void setCurVal(double curVal) {
      this.curVal = curVal;
      nCount++;
      range_avg += (curVal - range_avg)/nCount;          // compute the running average
      pwrSumAvg += (curVal * curVal - pwrSumAvg) / nCount;  // compute the running average of squares
      if(nCount>1){
        range_std = sqrt((float) (pwrSumAvg * nCount - nCount * range_avg * range_avg) / (nCount - 1) );    // compute running standard deviation
      }  
    }
    
    public double getCurVal() {
      return this.curVal;
    }
    
    public double computePoint(double x,int pos) {
      return curVal;
    }
}

void setup(){
    size(1500,700, P3D);
    surface.setResizable(true);
    stroke(0,0,0);
    colorMode(RGB, 256); 
    
    try{
      myPort = new Serial(this, portName, 115200);
      myPort.clear();
      myPort.bufferUntil(lf);
    }catch(Exception e){
      println("Cannot open serial port.");
    }
    
    // initialize the 2D map
    position_data = new positionDataHistory();
    map = new Graph2D(this, 800, 600, false);
    
     // initialize running traces with range and RSS information
    g_range = new Graph2D(this, 500, 300, false);
    g_rss = new Graph2D(this, 500, 150, false); 
    
    range_data = new ArrayList<rangeData>();
    rss_data = new ArrayList<rangeData>();    
    
    for(int i=0; i<NUM_ANCHORS; i++){
      rangeData r = new rangeData();
      range_data.add(r);
      RollingLine2DTrace rl = new RollingLine2DTrace(r ,100,0.1f);
      rl.setTraceColour(rgb_color[i%10], rgb_color[(i+1)%10], rgb_color[(i+2)%10]);
      rl.setLineWidth(2);      
      g_range.addTrace(rl);
      
      r = new rangeData();
      rss_data.add(r);
      rl = new RollingLine2DTrace(r ,100,0.1f);
      rl.setTraceColour(rgb_color[i%10], rgb_color[(i+1)%10], rgb_color[(i+2)%10]);
      rl.setLineWidth(2);      
      g_rss.addTrace(rl);
    }
    
    // initialize the graph displaying the distances
    g_range.setYAxisMin(-0.0f);
    g_range.setYAxisMax(10.0f);
    g_range.position.y = 40;
    g_range.position.x = 75;    
    g_range.setYAxisTickSpacing(1.f);
    g_range.setXAxisMax(5f);
    g_range.setXAxisLabel("time (s)");
    g_range.setYAxisLabel("distance (m)");
    g_range.setBackground(new SolidColourBackground(new GWColour(0f,0f,0f)));
    
    // initialize the graph displaying the received signal strength (RSS)
    g_rss.setYAxisMin(-120.0f);
    g_rss.setYAxisMax(-50.0f);
    g_rss.position.y = 480;
    g_rss.position.x = 75;    
    g_rss.setYAxisTickSpacing(10.0f);
    g_rss.setXAxisMax(5f);
    g_rss.setXAxisLabel("time (s)");
    g_rss.setYAxisLabel("RSS (dBm)");
    g_rss.setBackground(new SolidColourBackground(new GWColour(0f,0f,0f)));    
}

void draw(){
    background(126,161,172);
    
    fill(0,0,0);
    text("(c) Pozyx Labs", width-100, 20);  
    
    drawRange();    
    drawMap();
    
}

void drawRange(){
  
  // we draw the 2 graphs
  g_range.draw();
  g_rss.draw();  
  
  fill(0);                        
  text("Range measurements",20,30);  
  
  
  // we add some additional textual information about the ranges: mean distance and the standard deviation.
  fill(0); 
  strokeWeight(2);
  pushMatrix();
  translate(50,380);
  
  text("Press [space] to reset the signal statistics",240, 6);
  
  for(int i=0; i<4; i++)
  {
      stroke(rgb_color[i%10], rgb_color[(i+1)%10], rgb_color[(i+2)%10]);
      line(0, 6+i*18, 10, 6+i*18);
      text("Average: "+ String.format("%.3f", range_data.get(i).get_range_avg()) + "m", 20, 12+i*18);
      text("Std. dev.: "+ String.format("%.3f", range_data.get(i).get_range_std()) + "m", 140, 12+i*18);   
  }
  popMatrix();
  
}
  
void drawMap(){

  // draw the plane
  stroke(0);
  fill(255);
  rect(plane_x,plane_y , plane_width , plane_height);
  
  calculateAspectRatio();
  
  pushMatrix();  
    
  translate(plane_x + (border * pixel_per_mm),plane_y + plane_height - (border * pixel_per_mm));
  rotateX(radians(180));
  fill(0);
  
  // draw the grid
  strokeWeight(1);
  stroke(200);
  for(int i = 0; i < (int) plane_width/pixel_per_mm/thick_mark ; i++)
    line(i * thick_mark * pixel_per_mm, -(thick_mark * pixel_per_mm), i * thick_mark * pixel_per_mm, plane_height -(thick_mark * pixel_per_mm));
    
  stroke(100);
  for(int i = 0; i < (int) plane_height/pixel_per_mm/thick_mark - 1 ; i++)
    line(-(thick_mark * pixel_per_mm), i * thick_mark * pixel_per_mm, plane_width-(thick_mark * pixel_per_mm),  (i* thick_mark * pixel_per_mm));
  
  // draw the anchors
  for(int i=0; i < anchors[0].length ; i ++){
    drawAnchor(i, anchors[0][i], anchors[1][i]);
    
  }
    
  stroke(0);
  fill(0);
  drawArrow(0, 0, 50, 0.);
  drawArrow(0, 0, 50, 90.);
  pushMatrix();
  rotateX(radians(180));
  text("X", 55, 5);  
  text("Y", -3, -55);
  popMatrix();

  // finally, we plot the user position  
  fill(0,128,0);
  int[] current_position = position_data.getCurPosition();
  ellipse(pixel_per_mm * current_position[0], pixel_per_mm* current_position[1], 20, 20);
    
  popMatrix();  
}

void calculateAspectRatio(){
  
  if(anchors[0].length != 0){
  
    int max_width_mm = max(anchors[0]) + 2*border; 
    int max_height_mm = max(anchors[1])+ 2*border; 
    
    
    if ((float) max_width_mm / plane_width > (float) max_height_mm / plane_height){
      pixel_per_mm = (float)plane_width /  max_width_mm;
    }
    else{
      pixel_per_mm = (float)plane_height /  max_height_mm;
    }
  }
}

void drawAnchor(int i, int x, int y){
  
  int size = 20;  
  
  stroke(rgb_color[i%10], rgb_color[(i+1)%10], rgb_color[(i+2)%10]);
  fill(rgb_color[i%10], rgb_color[(i+1)%10], rgb_color[(i+2)%10]);

  rect(pixel_per_mm * x - size/2, pixel_per_mm * y - size/2, size, size, 5);
  
  pushMatrix();
  rotateX(radians(180));
  fill(0);
  textSize(11);
  text(anchor_ids[i], pixel_per_mm * x - size/2, -  (pixel_per_mm * y) + size + 2);
  textSize(12);
  popMatrix();
  
}

void drawArrow(int cx, int cy, int len, float angle){
  pushMatrix();
  translate(cx, cy);
  rotate(radians(angle));
  line(0,0,len, 0);
  line(len, 0, len - 8, -8);
  line(len, 0, len - 8, 8);
  popMatrix();
}

// This is where we read
void serialEvent(Serial p) {
  
inString = (myPort.readString());
  print(inString);  
  try {
    //Parse the data
    // expected string: POS,network_id,posx,posy,posz,errx,erry,errz,errXY,errXZ,errYZ,range1,rss1,...
    // expected string: ANCHOR,network_id,posx,posy,posz
    
    String[] dataStrings = split(inString, ',');
   
    if (dataStrings[0].equals("ANCHOR")){
      
      anchor_ids = append(anchor_ids, dataStrings[1]);
      
      anchors[0] = append(anchors[0], int(dataStrings[2]));
      anchors[1] = append(anchors[1], int(dataStrings[3]));
      anchors[2] = append(anchors[2], int(dataStrings[4]));
      anchors[3] = append(anchors[3], 10000);
      
      if (anchor_ids.length == NUM_ANCHORS){
        calculateAspectRatio();
      }
      
    }
    
    if (dataStrings[0].equals("POS")){
      // TODO multiple arrays for multitag
      // networkId = dataStrings[1]
      position_data.addPosition(int(dataStrings[2]), int(dataStrings[3]), int(dataStrings[4]));
      position_data.addError(int(dataStrings[5]), int(dataStrings[6]), int(dataStrings[7]), int(dataStrings[8]), int(dataStrings[9]), int(dataStrings[10]));
      
      for( int i = 0; i < NUM_ANCHORS; i++){
         anchors[3][i] = int(dataStrings[11+(i*2)]);
         //println(dataStrings[11+(i*2)]);
         range_data.get(i).setCurVal(float(dataStrings[11+(i*2)])/1000.0f);
         rss_data.get(i).setCurVal(float(dataStrings[12+(i*2)]));
      }     
    }
    
  } catch (Exception e) {
      println("Error while reading serial data.");
  }
  
}

void keyPressed() {
  
  // reset the mean and standard deviation
  for(int i = 0; i < NUM_ANCHORS; i++){
        range_data.get(i).reset_statistics();        
  }
  println("Resetting statistics.");  
}