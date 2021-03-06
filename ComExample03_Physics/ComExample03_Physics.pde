// Kinect Physics Example by Amnon Owed (15/09/12)
// edited by Arindam Sen
// updated for openProcessing library and Processing 3 by Erik Nauman 9/16
// updated for KinectPV2 by Harold Sikkema, February 2019
// see http://codigogenerativo.com/code/kinectpv2-k4w2-processing-library/

// import libraries
import KinectPV2.*;
import blobDetection.*; // blobs
import toxi.geom.*; // toxiclibs shapes and vectors
import toxi.processing.*; // toxiclibs display
import shiffman.box2d.*; // shiffman's jbox2d helper library
import org.jbox2d.collision.shapes.*; // jbox2d
import org.jbox2d.dynamics.joints.*;
import org.jbox2d.common.*; // jbox2d
import org.jbox2d.dynamics.*; // jbox2d

//Kinect kinect;
KinectPV2 kinect;
// declare BlobDetection object
BlobDetection theBlobDetection;
// ToxiclibsSupport for displaying polygons
ToxiclibsSupport gfx;
// declare custom PolygonBlob object (see class for more info)
PolygonBlob poly;

// PImage to hold incoming imagery and smaller one for blob detection
PImage cam;
PImage blobs;

// the kinect's bodyTrackImage dimensions to be used later on for calculations
int kinectWidth = 512;
int kinectHeight = 424;

// multiplier used to center and rescale to higher custom resolutions
float reScale;

// background and blob color
color bgColor, blobColor;
// three color palettes 
// (artifact from me storingmany interesting color palettes as strings in an external data file ;-)
String[] palettes = {
  "-1117720,-13683658,-8410437,-9998215,-1849945,-5517090,-4250587,-14178341,-5804972,-3498634", 
  "-67879,-9633503,-8858441,-144382,-4996094,-16604779,-588031", 
  "-1978728,-724510,-15131349,-13932461,-4741770,-9232823,-3195858,-8989771,-2850983,-10314372"
};
color[] colorPalette;

// the main PBox2D object in which all the physics-based stuff is happening
Box2DProcessing box2d;
// list to hold all the custom shapes (circles, polygons)
ArrayList<CustomShape> polygons = new ArrayList<CustomShape>();

void setup() {
  println("SET UP");
  // it's possible to customize this, for example 1920x1080
   size(1920,1080,P3D);
  //fullScreen(P3D);
  kinect = new KinectPV2(this);
  kinect.enableBodyTrackImg(true);
  kinect.init();
  
  // calculate the reScale value
  // currently it's rescaled to fill the complete width (cuts of top-bottom)
  // it's also possible to fill the complete height (leaves empty sides)
  reScale = (float) width / kinectWidth;
  // create a smaller blob image for speed and efficiency
  blobs = createImage(kinectWidth/3, kinectHeight/3, RGB);
  // initialize blob detection object to the blob image dimensions
  theBlobDetection = new BlobDetection(blobs.width, blobs.height);
  theBlobDetection.setThreshold(0.3);
  // initialize ToxiclibsSupport object
  gfx = new ToxiclibsSupport(this);
  // setup box2d, create world, set gravity
  box2d = new Box2DProcessing(this);
  box2d.createWorld();
  box2d.setGravity(0, -40);
  // set random colors (background, blob)
  setRandomColors(1);

  float gap = kinectWidth / 21;
  for (int i=0; i<20; i++)
  {
    drawString(gap * (i+1), 2, 10);
  }
}

void drawString(float x, float size, int cards) {

  float gap = kinectHeight/cards;
  // anchor card
  CustomShape s1 = new CustomShape(x, -40, size, BodyType.DYNAMIC);
  polygons.add(s1);

  CustomShape last_shape = s1;
  CustomShape next_shape;
  for (int i=0; i<cards; i++)
  {
    float y = -20 + gap * (i+1);
    next_shape = new CustomShape(x, -20 + gap * (i+1), size, BodyType.DYNAMIC);
    DistanceJointDef jd = new DistanceJointDef();

    Vec2 c1 = last_shape.body.getWorldCenter();
    Vec2 c2 = next_shape.body.getWorldCenter();
    // offset the anchors so the cards hang vertically
    c1.y = c1.y + size / 5;
    c2.y = c2.y - size / 5;
    jd.initialize(last_shape.body, next_shape.body, c1, c2);
    jd.length = box2d.scalarPixelsToWorld(gap - 1);
    box2d.createJoint(jd);
    polygons.add(next_shape);
    last_shape = next_shape;
  }
}

void draw() {
  background(bgColor);
  PImage cam = kinect.getBodyTrackImage();
  // copy the image into the smaller blob image
  blobs.copy(cam, 0, 0, cam.width, cam.height, 0, 0, blobs.width, blobs.height);
  // blur the blob image, otherwise too many blog segments
  blobs.filter(BLUR, 2);
  // detect the blobs
  theBlobDetection.computeBlobs(blobs.pixels);
  // initialize a new polygon
  poly = new PolygonBlob();
  // create the polygon from the blobs (custom functionality, see class)
  poly.createPolygon();
  // create the box2d body from the polygon
  poly.createBody();
  // update and draw everything (see method)
  updateAndDrawBox2D();
  // destroy the person's body (important!)
  poly.destroyBody();
  // set the colors randomly every 240th frame
  setRandomColors(240);
}

void updateAndDrawBox2D() {
  // if frameRate is sufficient, add a polygon and a circle with a random radius

  if (frameRate > 24) {
    CustomShape shape1 = new CustomShape(kinectWidth/2, -50, -1, BodyType.DYNAMIC) ;
    CustomShape shape2 = new CustomShape(kinectWidth/2, -50, random(2.5, 20), BodyType.DYNAMIC);
    polygons.add(shape1);
    polygons.add(shape2);
  }
  // take one step in the box2d physics world
  box2d.step();

  // center and reScale from Kinect to custom dimensions
  translate(0, (height-kinectHeight*reScale)/2);
  scale(reScale);

  // display the person's polygon  
  noStroke();
  fill(blobColor);
  gfx.polygon2D(poly);

  // display all the shapes  (circles, polygons)
  // go backwards to allow removal of shapes
  for (int i=polygons.size()-1; i>=0; i--) {
    CustomShape cs = polygons.get(i);
    // if the shape is off-screen remove it (see class for more info)

    if (cs.done()) {
      polygons.remove(i);
      // otherwise update (keep shape outside person) and display polygon
    } else {
      cs.update();
      cs.display();
    }
  }
}


// sets the colors every nth frame
void setRandomColors(int nthFrame) {
  if (frameCount % nthFrame == 0) {
    // turn a palette into a series of strings
    String[] paletteStrings = split(palettes[int(random(palettes.length))], ",");
    // turn strings into colors
    colorPalette = new color[paletteStrings.length];
    for (int i=0; i<paletteStrings.length; i++) {
      colorPalette[i] = int(paletteStrings[i]);
    }
    // set background color to first color from palette
    bgColor = colorPalette[0];
    // set blob color to second color from palette
    blobColor = colorPalette[1];
    // set all shape colors randomly
    for (CustomShape cs : polygons) { 
      cs.col = getRandomColor();
    }
  }
}

// returns a random color from the palette (excluding first aka background color)
color getRandomColor() {
  return colorPalette[int(random(1, colorPalette.length))];
}
