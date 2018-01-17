/**
  The Pozyx Ready to Localize Processing Example (c) Pozyx

  This is a Processing example that can be used to visualise positioning data.
  Positioning data can be obtained from three sources:
  
   - a Serial connection to an Arduino running the Ready to Localize tutorial sketch
       https://www.pozyx.io/Documentation/Tutorials/ready_to_localize/Arduino
       
   - the OSC protocol to get data provided by the Python Ready to Localize tutorial script
       https://www.pozyx.io/Documentation/Tutorials/ready_to_localize/Python
       
   - the MQTT protocol to get data provided by the Pozyx web app
       https://bapp.cloud.pozyxlabs.com
  
  
  Required Processing libraries:
   - oscP5
   - MQTT
  
  The libraries need to be downloaded through the Library Manager.
  Select "Add Library..." from the "Import Library..." submenu within the Sketch menu.
*/

import processing.serial.*;
import oscP5.*;
import mqtt.*;
import java.lang.Math.*;
import java.lang.reflect.*;

// Helper enumeration
enum Protocol {
  SERIAL, OSC, MQTT
}

// Helper class
class PozyxDevice{
  private int ID = 0;
  private int x = 0;
  private int y = 0;
  private int z = 0;
  private boolean success = false;
  
  public PozyxDevice(int ID){
    this.ID = ID;
  }
  
  public void setPosition(int x, int y, int z){
    this.x = x;
    this.y = y;
    this.z = z;
    this.success = true;
  }
  
  public void setSuccess(boolean success) {
    this.success = success;
  }
  
  public int getX(){
    return x;
  }
  public int getY(){
    return y;
  }
  public int getZ(){
    return z;
  }
  public boolean getSuccess(){
    return success;
  }
}

// custom MQTT class, added connection lost functionality
public class PozyxMQTTClient extends MQTTClient {
  PApplet parent;
  Method connectionLostMethod;
  
  public PozyxMQTTClient(PApplet parent) {
    super(parent);
    this.parent = parent;
    connectionLostMethod = findCallback("connectionLost");
  }
  
  @Override
  public void connectionLost(Throwable throwable) {
    if(connectionLostMethod != null) {
      try {
        connectionLostMethod.invoke(parent);
      } catch (Exception e) {
        System.out.println("[MQTT] lost connection!" + throwable.getMessage());
        System.out.println(e);
      }
    } else {
      System.out.println("[MQTT] lost connection!" + throwable.getMessage());
    }
  }
  
  private Method findCallback(final String name) {
    try {
      return parent.getClass().getMethod(name, String.class, byte[].class);
    } catch (Exception e) {
      System.out.println("[MQTT] connectionLostMethod callback not found!");
      return null;
    }
  }
}

/////////////////////////////////////////////////////////////
////////////////////////  Parameters ////////////////////////
/////////////////////////////////////////////////////////////

Protocol protocol = Protocol.MQTT;  // set to the protocol you want to use: SERIAL, OSC or MQTT

// Serial protocol parameters
String serialPort = "COM24";        // set to correct serial port if you use serial communication

// OSC protocol parameters
int oscPort = 8888;                 // set to correct UDP port when using OSC

// MQTT protocol parameters
// Find these in the web app Settings (https://bapp.cloud.pozyxlabs.com/settings)
//  -> API keys
String TENANT_ID = "5a39662d3a3f2a0005180fd6";
String API_KEY = "d342fcc5-e050-409e-bce0-1e95e0e4108a";

// GUI settings
int border = 30;                    // size of the border around the map
int margin = 1000;                  // margin around objects on the map in mm
int grid_distance = 1000;           // mm between gridlines
int device_size = 15;               // radius of the devices
float default_scale_ratio = 0.1;  // default scale of the map

/////////////////////////////////////////////////////////////
///////////////////   Global  Variables   ///////////////////
/////////////////////////////////////////////////////////////

// Communication objects
Serial myPort;
String inString;
OscP5 oscP5;
MQTTClient client;

// GUI variables
int map_width, map_height;
int max_x = 0;
int max_y = 0;
int min_x = 0;
int min_y = 0;
float scale_ratio;

// List of pozyx devices
PozyxDevice[] pozyxDevices = {};


/////////////////////////////////////////////////////////////
//////////////////////  Main  Program  //////////////////////
/////////////////////////////////////////////////////////////

// Processing Settings
void settings() {
  size(800, 600);
}


// Setup function is run once
void setup(){  
  // duration of start communication can give rendering errors => new thread
  thread("startCommunication");
  
  surface.setResizable(true);
  background(51,125,154);
  
  // calculate map dimensions
  map_width = width - 2 * border;
  map_height = height - 2 * border;
  
  // set starting scale
  resetScale();
}

// Draw function is run continuously
void draw(){
  // P2D and P3D renderer need scaling
  translate(0, 29);
  scale(1, height/(height+33.0));
  
  fill(0);
  fill(255);
  textSize(14);
  textAlign(CENTER, TOP);
  text("(c) Pozyx Labs", width/2, 10);
  
  drawMap();
}


/////////////////////////////////////////////////////////////
///////////////////// Drawing Functions /////////////////////
/////////////////////////////////////////////////////////////

void drawMap(){
  // calculate map dimensions
  map_width = width - 2 * border;
  map_height = height - 2 * border;
  
  // draw map area
  stroke(0);
  strokeWeight(1);
  fill(255);
  rect(border, border, map_width, map_height);
  
  // set origin and axis direction to map
  translate(border, height-border);
  scale(1, -1);
  
  // calculate map margins and range and set origin and scale in map
  calculateScale();
  int map_min_x = min_x;
  int map_range_x = floor(map_width/scale_ratio);
  int map_max_x = map_min_x + map_range_x;
  int map_min_y = min_y;
  int map_range_y = floor(map_height/scale_ratio);
  int map_max_y = map_min_y + map_range_y;
  scale(scale_ratio);
  translate(-map_min_x, -map_min_y);
  
  // draw the grid
  strokeWeight(8);
  for(int i = ceil(map_min_x / grid_distance); i*grid_distance < map_max_x; i++)
    line(i * grid_distance, map_min_y, i * grid_distance, map_max_y);
  for(int i = ceil(map_min_y / grid_distance); i*grid_distance < map_max_y; i++)
    line(map_min_x, i * grid_distance, map_max_x, i * grid_distance);
  
  // draw devices
  drawDevices();
  
  // draw origin
  scale(1/scale_ratio); // Always the same size
  stroke(0);
  strokeWeight(4);
  fill(0, 0, 0);
  textSize(16);
  drawArrow(0, 0, 50, 0.);
  textAlign(LEFT, CENTER);
  upsideDownText("X", 55, 0);
  drawArrow(0, 0, 50, 90.);
  textAlign(CENTER, BOTTOM);
  upsideDownText("Y", 0, 55);
}


// Calculate scale to adjust for devices going out of the map range
void calculateScale() {
  if (pozyxDevices.length > 0) {
    for (PozyxDevice pozyxDevice : pozyxDevices){
      min_x = min(min_x, pozyxDevice.getX()-margin);
      max_x = max(max_x, pozyxDevice.getX()+margin);
      min_y = min(min_y, pozyxDevice.getY()-margin);
      max_y = max(max_y, pozyxDevice.getY()+margin);
    }
  }
  scale_ratio = min((float)map_width / (max_x - min_x + 2*margin), (float)map_height / (max_y - min_y + 2*margin));
}


// Draw all tracked devices on the map
void drawDevices(){
  for(PozyxDevice pozyxDevice : pozyxDevices){
    drawDevice(pozyxDevice.ID, pozyxDevice.getX(), pozyxDevice.getY(), pozyxDevice.getSuccess());
  }
}


// Draw a circle to represent a tracked device, red circle when something is wrong
void drawDevice(int ID, int x, int y, boolean success){
  pushMatrix();
  translate(x, y);
  scale(1/scale_ratio);
  if (success) {
    fill(0);
  } else {
    fill(255, 0, 0);
  }
  noStroke();
  ellipse(0, 0, device_size, device_size);
  textAlign(LEFT, CENTER);
  textSize(16);
  upsideDownText("0x" + hex(ID, 4), device_size + 3, 0);
  popMatrix();
}


// Draw text upside down according to the current scale, most of the time this means the text is upright
void upsideDownText(String text, float x, float y) {
  pushMatrix();
  translate(x, y);
  scale(1, -1);
  text(text, 0, 0);
  popMatrix();
}


void drawArrow(int start_x, int start_y, int len, float angle){
  pushMatrix();
  translate(start_x, start_y);
  rotate(radians(angle));
  line(0,0,len, 0);
  line(len, 0, len - 8, -4);
  line(len, 0, len - 8, 4);
  popMatrix();
}


// Called whenever a key on the keyboard is pressed
void keyPressed() {
  resetScale();
  println("Resetting area size");  
}


// Reset the scale to the current area taken by the devices. Useful if you moved too much outside of the anchor area.
void resetScale() {
  scale_ratio = default_scale_ratio;
  max_x = floor(((width - border*2) / scale_ratio) - margin);
  max_y = floor(((height - border*2) / scale_ratio) - margin);
  min_x = -margin;
  min_y = -margin;
}

/////////////////////////////////////////////////////////////
////////////////// Communication Functions //////////////////
/////////////////////////////////////////////////////////////

void startCommunication() {
  switch(protocol) {
    case SERIAL:
      try {
        myPort = new Serial(this, serialPort, 115200);
        myPort.clear();
        myPort.bufferUntil(10); // Buffer until line feed character (10)
      } catch(Exception e) {
        println("Cannot open serial port.");
      }
      break;
    case OSC:
      try {
        oscP5 = new OscP5(this, oscPort);
      } catch(Exception e) {
        println("Cannot open UDP port");
      }
      break;
    case MQTT:
      client = new MQTTClient(this);
      client.connect("wss://" + TENANT_ID + ":" + API_KEY + "@mqtt.cloud.pozyxlabs.com:443");
      client.subscribe(TENANT_ID);
      println("MQTT subscribed");
      break;
  }
}


// Called whenever a serial communication message is received
void serialEvent(Serial p) {
  // Read message from serial port
  inString = myPort.readString();
  
  // Debugging
  // println(inString);
  
  // Parse the message
  // Expected String: POS/ANCHOR,network_id,posx,posy,posz
  try {
    String[] dataStrings = split(inString, ',');
    if (dataStrings[0].equals("POS") || dataStrings[0].equals("ANCHOR")){
      int id = Integer.parseInt(split(dataStrings[1], 'x')[1].trim(), 16);
      addPosition(id, int(dataStrings[2].trim()), int(dataStrings[3].trim()), int(dataStrings[4].trim()));
    }
  } catch (Exception e) {
      println("Error while reading serial data.");
  }
}


// Called whenever an OSC protocol message is received
void oscEvent(OscMessage theOscMessage) {
  // Debugging
  // println(theOscMessage);
  
  // Parse the message
  if (theOscMessage.addrPattern().equals("/position") || theOscMessage.addrPattern().equals("/anchor")){
    try {
      addPosition(theOscMessage.get(0).intValue(), theOscMessage.get(1).intValue(), theOscMessage.get(2).intValue(), theOscMessage.get(3).intValue());
    } catch(Exception e) {
      println("Error while receiving OSC position");
    }
  }
}


// Called whenever an MQTT packet is received
void messageReceived(String topic, byte[] payload) {
  // Debugging
  // println(new String(payload));
  
  // Parse the packet
  JSONArray arrayJson = JSONArray.parse(new String(payload));
  for (int i = 0; i < arrayJson.size(); i++) {
    JSONObject tag = arrayJson.getJSONObject(i);
      int tagId = tag.getInt("tagId");
      boolean success = tag.getBoolean("success");
      if (success) {
        JSONObject data = tag.getJSONObject("data");
        JSONObject coordinates = data.getJSONObject("coordinates");
        if (coordinates != null) {
          int x = coordinates.getInt("x");
          int y = coordinates.getInt("y");
          int z = coordinates.getInt("z");
          addPosition(tagId, x, y, z);
        } else {
          setSuccess(tagId, false);
        }
      } else {
        setSuccess(tagId, false);
      }
  }
}

// Called when MQTT connection is lost
void connectionLost() {
  // reconnect
  thread("startCommunication");
}


// Helper function to add position to Device list
void addPosition(int ID, int x, int y, int z) {
  // Search ID in device list
  for(PozyxDevice pozyxDevice : pozyxDevices) {
    if (pozyxDevice.ID == ID) {
      // ID in device list, set position of found device
      pozyxDevice.setPosition(x, y, z);
      return;
    }
  }
  
  // ID not in device list, add new device
  PozyxDevice newPozyx = new PozyxDevice(ID);
  newPozyx.setPosition(x, y, z);
  pozyxDevices = (PozyxDevice[]) append(pozyxDevices, newPozyx);
}

// Helper function to set success to Device list
void setSuccess(int ID, boolean success) {
  // Search ID in device list
  for(PozyxDevice pozyxDevice : pozyxDevices) {
    if (pozyxDevice.ID == ID) {
      // ID in device list, set position of found device
      pozyxDevice.setSuccess(success);
      return;
    }
  }
  
  // ID not in device list, add new device
  PozyxDevice newPozyx = new PozyxDevice(ID);
  newPozyx.setSuccess(success);
  pozyxDevices = (PozyxDevice[]) append(pozyxDevices, newPozyx);
}