import oscP5.*;
import org.gwoptics.graphics.graph2D.Graph2D;
import org.gwoptics.graphics.graph2D.traces.*;
import org.gwoptics.graphics.graph2D.backgrounds.*;
import org.gwoptics.graphics.GWColour;
import processing.serial.*;
import java.lang.Math.*;

boolean serial = false;          // set to true to use Serial, false to use OSC messages.

int oscPort = 8888;               // change this to your UDP port
String serialPort = "COM13";      // change this to your COM port 


/////////////////////////////////////////////////////////////
//////////////////////  variables //////////////////////////
/////////////////////////////////////////////////////////////

OscP5 oscP5;
Serial myPort;

int     lf = 10;       //ASCII linefeed
String  inString;      //String for testing serial communication
int[] rgb_color = {0, 0, 255, 0, 160, 122, 0, 255, 0, 255};

Graph2D g_acc, g_gyro, g_mag;
PImage compass_img;

/////////////////////////////////////////////////////////////
///////////// sensordata variables //////////////////////////
/////////////////////////////////////////////////////////////

float x_angle = 0;  
float y_angle = 0;
float z_angle = 0;

float speed_x = 0;
float speed_y = 0;
float speed_z = 0;

float lin_acc_x = 0;
float lin_acc_y = 0;
float lin_acc_z = 0;

float quat_w, quat_x, quat_y, quat_z;
float grav_x, grav_y, grav_z;
float heading = 0;
float pressure = 0;

String calib_status = "";

// array of sensor data over multiple timesteps
ArrayList<rangeData> accData;
ArrayList<rangeData> magData;
ArrayList<rangeData> gyroData;
 
 
/////////////////////////////////////////////////////////////
///////// class needed for the timeseries graph /////////////
/////////////////////////////////////////////////////////////

class rangeData implements ILine2DEquation{
    private double curVal = 0;

    public void setCurVal(double curVal) {
      this.curVal = curVal;      
    }
    
    public double getCurVal() {
      return this.curVal;
    }
    
    public double computePoint(double x,int pos) {
      return curVal;
    }
}



void setup(){
  size(1100,800, P3D);
  surface.setResizable(true);
  stroke(0,0,0);
  colorMode(RGB, 256); 
     
  compass_img = loadImage("compass.png");
 
  if(serial){
    try{
      myPort = new Serial(this, serialPort, 115200);
      myPort.clear();
      myPort.bufferUntil(lf);
    }catch(Exception e){
      println("Cannot open serial port.");
    }
  }else{
    try{
      oscP5 = new OscP5(this, oscPort);
    }catch(Exception e){
      println("Cannot open UDP port");
    }
  }
  
       
  // initialize running traces 
  g_acc = new Graph2D(this, 400, 200, false);
  g_mag = new Graph2D(this, 400, 200, false);
  g_gyro = new Graph2D(this, 400, 200, false);   
  
  accData = new ArrayList<rangeData>();
  magData = new ArrayList<rangeData>();
  gyroData = new ArrayList<rangeData>();    
  for(int i=0; i<3; i++){
    rangeData r = new rangeData();
    accData.add(r);
    RollingLine2DTrace rl = new RollingLine2DTrace(r ,100,0.1f);
    rl.setTraceColour(rgb_color[i%10], rgb_color[(i+1)%10], rgb_color[(i+2)%10]);
    rl.setLineWidth(2);      
    g_acc.addTrace(rl);
    
    r = new rangeData();
    magData.add(r);
    rl = new RollingLine2DTrace(r ,100,0.1f);
    rl.setTraceColour(rgb_color[i%10], rgb_color[(i+1)%10], rgb_color[(i+2)%10]);
    rl.setLineWidth(2);      
    g_mag.addTrace(rl);
    
    r = new rangeData();
    gyroData.add(r);
    rl = new RollingLine2DTrace(r ,100,0.1f);
    rl.setTraceColour(rgb_color[i%10], rgb_color[(i+1)%10], rgb_color[(i+2)%10]);
    rl.setLineWidth(2);      
    g_gyro.addTrace(rl);    
   
  }
  
  // create the accelerometer graph
  g_acc.setYAxisMin(-2.0f);
  g_acc.setYAxisMax(2.0f);
  g_acc.position.y = 50;
  g_acc.position.x = 100;    
  g_acc.setYAxisTickSpacing(0.5f);
  g_acc.setXAxisMax(5f);
  g_acc.setXAxisLabel("time (s)");
  g_acc.setYAxisLabel("acceleration [g]");
  g_acc.setBackground(new SolidColourBackground(new GWColour(1f,1f,1f)));
  
  // create the magnetometer graph
  g_mag.setYAxisMin(-80.0f);
  g_mag.setYAxisMax(80.0f);
  g_mag.position.y = 300;
  g_mag.position.x = 100;    
  g_mag.setYAxisTickSpacing(40f);
  g_mag.setXAxisMax(5f);
  g_mag.setXAxisLabel("time (s)");
  g_mag.setYAxisLabel("magnetic field strength [µT]");
  g_mag.setBackground(new SolidColourBackground(new GWColour(1f,1f,1f)));
  
  // create the gyrometer graph
  g_gyro.setYAxisMin(-1000.0f);
  g_gyro.setYAxisMax(1000.0f);
  g_gyro.position.y = 550;
  g_gyro.position.x = 100;    
  g_gyro.setYAxisTickSpacing(250f);
  g_gyro.setXAxisMax(5f);
  g_gyro.setXAxisLabel("time (s)");
  g_gyro.setYAxisLabel("angular velocity [deg/s]");
  g_gyro.setBackground(new SolidColourBackground(new GWColour(1f,1f,1f)));
  
}

void draw(){
    background(126,161,172);
       
    // show some text
    fill(0,0,0);
    text("(c) Pozyx Labs", width-100, 20);
    text("Calibration status:", 550, 730);
    text(calib_status, 550, 750);   
    
    text("Pressure: " + pressure + "Pa", 550, 710);
       
    // draw the 3 graphs   
    g_acc.draw();
    g_mag.draw();
    g_gyro.draw();
    
    //Show 3D orientation data
    stroke(0,0,0);
    strokeWeight(0.01);
  
    pushMatrix();
    translate(800, 500, -50);
    
    rotateX(radians(-90));
    rotateZ(radians(90));
    quat_rotate(quat_w, quat_x, quat_y, quat_z);
    
    // draw the 3D box
    draw_rect(93, 175, 83);
    
    // draw lines
    strokeWeight(0.1);
    line(0,0,0, grav_x*2, grav_y*2, grav_z*2);    
    stroke(200,0,0);
    line(0,0,0, 0, 0, 1);
    
    // end rotation
    popMatrix();
    
    // show the linear acceleration in body coordinates
    int x_center = 700, y_center = 150;
    stroke(0,0,0);
    strokeWeight(1);
    line(x_center-75, y_center, x_center+75, y_center);
    line(x_center, y_center-75, x_center, y_center+75);
    ellipseMode(CENTER);
    ellipse(x_center, y_center, 50, 50);
    ellipse(x_center+lin_acc_x/50, y_center-lin_acc_y/50, 50*(1-lin_acc_z/1000), 50*(1-lin_acc_z/1000));
    fill(0,0,0);
    text("Linear acceleration\n(body coordinates)", x_center-50, y_center + 100);
    
    // show the linear acceleration in world coordinates
    x_center = 900;
    fill(93, 175, 83);
    stroke(0,0,0);
    strokeWeight(1);
    line(x_center-75, y_center, x_center+75, y_center);
    line(x_center, y_center-75, x_center, y_center+75);
    ellipseMode(CENTER);
    ellipse(x_center, y_center, 50, 50);
    
    PVector lin_acc = new PVector(lin_acc_x, lin_acc_y, lin_acc_z);
    //PVector lin_acc = new PVector(grav_x*1000.0f, grav_y*1000.0f, grav_z*1000.0f);    // test to verify the rotation
    lin_acc = quaternion_rotate(quat_w, quat_x, quat_y, quat_z, lin_acc);
    lin_acc.y = -lin_acc.y;
    lin_acc.z = -lin_acc.z;
       
    
    ellipseMode(CENTER);
    ellipse(x_center+lin_acc.x/50, y_center-lin_acc.y/50, 50*(1-lin_acc.z/1000), 50*(1-lin_acc.z/1000));
    fill(0,0,0);
    text("Linear acceleration\n(world coordinates)", x_center-50, y_center + 100);
    /*    
    text("x: " + grav_x*1000.0f , 550, 310);
    text("y: " + grav_y*1000.0f , 550, 330);
    text("z: " + grav_z*1000.0f , 550, 350);
    
    text("x: " + lin_acc_x , 550, 310);
    text("y: " + lin_acc_y , 550, 330);
    text("z: " + lin_acc_z , 550, 350);
    
    text("x: " + lin_acc.x , 650, 310);
    text("y: " + lin_acc.y , 650, 330);
    text("z: " + lin_acc.z , 650, 350);
    */
    
    // draw the heading (compass)
    int img_size = 160;
    image(compass_img, 1000-img_size/2, 700-img_size/2, img_size, img_size);
    stroke(255,0,0);
    strokeWeight(3);
    line(1000, 700, 1000+50*cos(radians(heading)), 700+50*sin(radians(heading))); 
    
    
    
}


void serialEvent(Serial p) {
  
  inString = (myPort.readString());
  println(inString);  
  
  try {
    //Parse the data
    String[] dataStrings = split(inString, ',');
    
    // the pressure from mPa to Pa is coming in at a slower rate
    pressure = float(dataStrings[1])/1000.0f;   
    
    // acceleration from mg to g
    accData.get(0).setCurVal(float(dataStrings[2])/1000.0f);      
    accData.get(1).setCurVal(float(dataStrings[3])/1000.0f);
    accData.get(2).setCurVal(float(dataStrings[4])/1000.0f);
    
    // magnetometer data in µT
    magData.get(0).setCurVal(float(dataStrings[5])/16.0f);      
    magData.get(1).setCurVal(float(dataStrings[6])/16.0f);
    magData.get(2).setCurVal(float(dataStrings[7])/16.0f);
    
    // gyroscope data in degrees per second
    gyroData.get(0).setCurVal(float(dataStrings[8])/16.0f);      
    gyroData.get(1).setCurVal(float(dataStrings[9])/16.0f);
    gyroData.get(2).setCurVal(float(dataStrings[10])/16.0f);
       
    // Euler angles in degrees    
    x_angle = float(dataStrings[13])/16.0f;
    y_angle = float(dataStrings[12])/16.0f;
    z_angle = float(dataStrings[11])/16.0f;
    heading = float(dataStrings[11])/16.0f;
    
    // the orientation quaternion
    quat_w = float(dataStrings[14])/16384.0f;
    quat_x = float(dataStrings[15])/16384.0f;
    quat_y = float(dataStrings[16])/16384.0f;
    quat_z = float(dataStrings[17])/16384.0f;
    float norm = PApplet.sqrt(quat_x * quat_x + quat_y * quat_y + quat_z
                * quat_z +quat_w * quat_w);
    quat_w = quat_w/norm;
    quat_x = quat_x/norm;
    quat_y = quat_y/norm;
    quat_z = quat_z/norm;  
    println(norm);
        
    // linear acceleration in mg    
    lin_acc_x = float(dataStrings[18]);
    lin_acc_y = float(dataStrings[19]);
    lin_acc_z = float(dataStrings[20]);
    
    // gravitation vector from mg to g
    grav_x = float(dataStrings[21])/16000.0f;
    grav_y = float(dataStrings[22])/16000.0f; 
    grav_z = float(dataStrings[23])/16000.0f;
    
    // the calibration status
    calib_status = "Mag: " + dataStrings[24] + " - Acc: " + dataStrings[25] + " - Gyro: " + dataStrings[26] + " - System: " + dataStrings[27];
                
  } catch (Exception e) {
      println("Error while reading serial data.");
  }
}

void oscEvent(OscMessage theOscMessage) {
  // osc message received
  println("### received an osc message with addrpattern "+theOscMessage.addrPattern()+" and typetag "+theOscMessage.typetag());
  if (theOscMessage.addrPattern().equals("/sensordata")){
    //theOscMessage.print();}
    try{
      // the pressure from mPa to Pa is coming in at a slower rate
      pressure = theOscMessage.get(1).floatValue();
      
      // acceleration from mg to g
      accData.get(0).setCurVal(theOscMessage.get(2).floatValue()/1000.0f);      
      accData.get(1).setCurVal(theOscMessage.get(3).floatValue()/1000.0f);
      accData.get(2).setCurVal(theOscMessage.get(4).floatValue()/1000.0f);
      
      // magnetometer data in µT
      magData.get(0).setCurVal(theOscMessage.get(5).floatValue());      
      magData.get(1).setCurVal(theOscMessage.get(6).floatValue());
      magData.get(2).setCurVal(theOscMessage.get(7).floatValue());
      
      // gyroscope data in degrees per second
      gyroData.get(0).setCurVal(theOscMessage.get(8).floatValue());      
      gyroData.get(1).setCurVal(theOscMessage.get(9).floatValue());
      gyroData.get(2).setCurVal(theOscMessage.get(10).floatValue());
      
      // Euler angles in degrees    
      x_angle = theOscMessage.get(13).floatValue();
      y_angle = theOscMessage.get(12).floatValue();
      z_angle = theOscMessage.get(11).floatValue();
      heading = theOscMessage.get(11).floatValue();
      
      // the orientation quaternion
      quat_w = theOscMessage.get(14).floatValue();
      quat_x = theOscMessage.get(15).floatValue();
      quat_y = theOscMessage.get(16).floatValue();
      quat_z = theOscMessage.get(17).floatValue();
      float norm = PApplet.sqrt(quat_x * quat_x + quat_y * quat_y + quat_z
                  * quat_z +quat_w * quat_w);     
      quat_w = quat_w/norm;
      quat_x = quat_x/norm;
      quat_y = quat_y/norm;
      quat_z = quat_z/norm;  
      println(norm);
      
      // linear acceleration in mg    
      lin_acc_x = theOscMessage.get(18).floatValue();
      lin_acc_y = theOscMessage.get(19).floatValue();
      lin_acc_z = theOscMessage.get(20).floatValue();
      
      // gravitation vector from mg to g
      grav_x = theOscMessage.get(21).floatValue()/1000.0f;
      grav_y = theOscMessage.get(22).floatValue()/1000.0f; 
      grav_z = theOscMessage.get(23).floatValue()/1000.0f;
      
      // the calibration status
      calib_status = "Mag: " + str(theOscMessage.get(24).intValue()) + " - Acc: " + str(theOscMessage.get(25).intValue()) + " - Gyro: " + str(theOscMessage.get(26).intValue()) + " - System: " + str(theOscMessage.get(27).intValue());
    }catch(Exception e){
      println("Error while receiving OSC sensor data");
    }
  }
}


void draw_rect(int r, int g, int b) {
  scale(100);
  beginShape(QUADS);
  
  fill(r, g, b);
  vertex(-1,  1.5,  0.25);
  vertex( 1,  1.5,  0.25);
  vertex( 1, -1.5,  0.25);
  vertex(-1, -1.5,  0.25);

  vertex( 1,  1.5,  0.25);
  vertex( 1,  1.5, -0.25);
  vertex( 1, -1.5, -0.25);
  vertex( 1, -1.5,  0.25);

  vertex( 1,  1.5, -0.25);
  vertex(-1,  1.5, -0.25);
  vertex(-1, -1.5, -0.25);
  vertex( 1, -1.5, -0.25);

  vertex(-1,  1.5, -0.25);
  vertex(-1,  1.5,  0.25);
  vertex(-1, -1.5,  0.25);
  vertex(-1, -1.5, -0.25);

  vertex(-1,  1.5, -0.25);
  vertex( 1,  1.5, -0.25);
  vertex( 1,  1.5,  0.25);
  vertex(-1,  1.5,  0.25);

  vertex(-1, -1.5, -0.25);
  vertex( 1, -1.5, -0.25);
  vertex( 1, -1.5,  0.25);
  vertex(-1, -1.5,  0.25);

  endShape();
  
}

public void quat_rotate(float w, float x, float y, float z) {
   float _x, _y, _z;
   //if (q1.w > 1) q1.normalise(); // if w>1 acos and sqrt will produce errors, this cant happen if quaternion is normalised
   double angle = 2 * Math.acos(w);
   float s = (float)Math.sqrt(1-w*w); // assuming quaternion normalised then w is less than 1, so term always positive.
   if (s < 0.001) { // test to avoid divide by zero, s is always positive due to sqrt
     // if s close to zero then direction of axis not important
     _x = x; // if it is important that axis is normalised then replace with x=1; y=z=0;
     _y = y;
     _z = z;
   } else {
     _x = x / s; // normalise axis
     _y = y / s;
     _z = z / s;
   }
   rotate((float)angle, _x, _y, _z);     
}

public final PVector quaternion_rotate(float w, float x, float y, float z, PVector v) { 
      
      float q00 = 2.0f * x * x;
      float q11 = 2.0f * y * y;
      float q22 = 2.0f * z * z;

      float q01 = 2.0f * x * y;
      float q02 = 2.0f * x * z;
      float q03 = 2.0f * x * w;

      float q12 = 2.0f * y * z;
      float q13 = 2.0f * y * w;

      float q23 = 2.0f * z * w;

      return new PVector((1.0f - q11 - q22) * v.x + (q01 - q23) * v.y
                      + (q02 + q13) * v.z, (q01 + q23) * v.x + (1.0f - q22 - q00) * v.y
                      + (q12 - q03) * v.z, (q02 - q13) * v.x + (q12 + q03) * v.y
                      + (1.0f - q11 - q00) * v.z);
      
}
