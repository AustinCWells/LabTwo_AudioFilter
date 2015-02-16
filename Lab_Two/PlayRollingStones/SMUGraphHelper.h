//
//  SMUGraphHelper.h
//  NovocaineExample
//
//  This is a collection of functions that act much like a protocol, but without the complexity (or the versatility)
//
//  Copyright (c) 2013 Eric Larson. All rights reserved.
//

#ifndef NovocaineExample_SMUGraphHelper_h
#define NovocaineExample_SMUGraphHelper_h
#define kGraphMaxSize 8000
#import <GLKit/GLKit.h>

enum PlotStyle {
    PlotStyleOverlaid,
    PlotStyleSeparated
};

struct point {
    GLfloat x;
    GLfloat y;
};

struct GraphBounds{
    float   top,
            bottom,
            left,
            right,
            center,
            middle,
            width,
            height;
    
    GraphBounds(float inBottom=-1.0,float inTop=1.0,float inLeft=-1.0, float inRight=1.0){
        top = inTop;
        bottom = inBottom;
        left = inLeft;
        right = inRight;
        center = (left+right)/2;
        middle = (top+bottom)/2;
        width = right-left;
        height = top-bottom;
    }
    
    void SetBounds(float inBottom=-1.0,float inTop=1.0,float inLeft=-1.0, float inRight=1.0){
        top = inTop;
        bottom = inBottom;
        left = inLeft;
        right = inRight;
        center = (left+right)/2;
        middle = (top+bottom)/2;
        width = right-left;
        height = top-bottom;
    }

};

struct GraphData{
    GraphData(){
        for(int i = 0; i < kGraphMaxSize; i++) {
            float x = (i - kGraphMaxSize/2) / 100.0;
            points[i].x = x;
            points[i].y = 0;
        }
        graphSize = kGraphMaxSize;
        maxGraphSize = kGraphMaxSize;
    }
    
    void SetColor(int k){
        //iOS7 color palette with gradients
        UInt8 R[] = {0xFF,0xFF, 0x52,0x5A, 0xFF,0xFF, 0x1A,0x1D, 0xEF,0xC6, 0xDB,0x89, 0x87,0x0B, 0xFF,0xFF, };
        UInt8 G[] = {0x5E,0x2A, 0xED,0xC8, 0xDB,0xCD, 0xD6,0x62, 0x4D,0x43, 0xDD,0x8C, 0xFC,0xD3, 0x95,0x5E, };
        UInt8 B[] = {0x3A,0x68, 0xC7,0xFB, 0x4C,0x02, 0xFD,0xF0, 0xB6,0xFC, 0xDE,0x90, 0x70,0x18, 0x00,0x3A, };
        
        for(int i = 0; i < kGraphMaxSize; i++) {
            float grad1 = ((float)i)/kGraphMaxSize;
            float grad2 = 1-grad1;
            float r = ( ((float)R[(2*k)%16])*grad1 + ((float)R[(2*k+1)%16])*grad2 )/255.0;
            float g = ( ((float)G[(2*k)%16])*grad1 + ((float)G[(2*k+1)%16])*grad2 )/255.0;
            float b = ( ((float)B[(2*k)%16])*grad1 + ((float)B[(2*k+1)%16])*grad2 )/255.0;
            
            colors[i] = GLKVector4Make(r,g,b,0.9); // set color
        }
        
    }
    
    point points[kGraphMaxSize];
    GLKVector4 colors[kGraphMaxSize];
    unsigned int graphSize;
    unsigned int maxGraphSize;
};


const GLfloat vertices[] = {
    0.1, 0.1,
    -0.1, 0.1,
    0.1,  -0.1,
    -0.1,  -0.1,
};
const GLfloat texCoords[] = {
    0., 1.,
    1., 1.,
    0., 0.,
    1., 0.,
};

typedef struct {
    float Position[2];
    float TexCoord[2]; // New
} Vertex;

// Add texture coordinates to Vertices as follows
const Vertex Vertices[] = {
    {{-0.5f, -0.5f}, {0.0f, 0.0f}}, // lower left corner
    {{ 0.5f, -0.5f}, {1.0f, 0.0f}}, // lower right corner
    {{-0.5f,  0.5f}, {0.0f, 1.0f}}  // upper left corner
};

// the graph helping class
class GraphHelper{
    
public:
    GraphHelper(GLKViewController *selfinput,
                int framesPerSecond=15,
                int numArrays=1,
                PlotStyle plotStyleInput=PlotStyleSeparated,
                int maxGraphSize=4096)
    {
        //================================================
        // setup the OpenGL view
        //================================================
        // init the context for using OpenGL, try for ES3.0 (supported on some devices, starting in iOS7)
        context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3];
        
        if (!context){
            // Fall back to the ES2.0, supported on most every device
            NSLog(@"OpenGL 3.0 not supported on device, trying 2.0");
            context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
        }
        
        if(!context){
            [NSException raise:@"Failed to create OpenGLES context, exiting"
                        format:@"Context is %@",context];
        }
        
        selfinput.preferredFramesPerSecond = framesPerSecond; // draw every 1/Nth of a second
        
        // cast the current view as GLKView (view must inherit from GLKView, set in storyboard)
        GLKView *view = (GLKView *)selfinput.view;
        view.context = context;
        
        [EAGLContext setCurrentContext:context];
        effect = [[GLKBaseEffect alloc] init];
        
        // setup data arrays for graphing
        bounds      = new GraphBounds();
        plotStyle   = plotStyleInput;
        numGraphs   = numArrays;
        graphs      = new GraphData[numArrays];
        vbo         = new GLuint[numArrays];
        color       = new GLuint[numArrays];
        
        // setup each line for OpenGL graphing
        for(int k=0;k<numGraphs;k++){
            graphs[k].SetColor(k);

            glGenBuffers(1, &vbo[k]);
            glBindBuffer(GL_ARRAY_BUFFER, vbo[k]);
            glBufferData(GL_ARRAY_BUFFER, sizeof(graphs[k].points), graphs[k].points, GL_DYNAMIC_DRAW);
            
            glGenBuffers(1, &color[k]);
            glBindBuffer(GL_ARRAY_BUFFER, color[k]);
            glBufferData(GL_ARRAY_BUFFER, sizeof(graphs[k].colors), graphs[k].colors, GL_STATIC_DRAW);
        }
        
//        glGenBuffers(1, &vertexTex);
//        glBindBuffer(GL_ARRAY_BUFFER, vertexTex);
//        glBufferData(GL_ARRAY_BUFFER, sizeof(Vertices), Vertices, GL_STATIC_DRAW);
//        
//        NSError *theError;
//        NSDictionary * options = [NSDictionary dictionaryWithObjectsAndKeys: [NSNumber numberWithBool:YES],GLKTextureLoaderOriginBottomLeft, nil];
//        NSString *filePath = [[NSBundle mainBundle] pathForResource:@"oscilloscope" ofType:@"png"];
//        spriteTexture = [GLKTextureLoader textureWithContentsOfFile:filePath options:options error:&theError];
//        if (spriteTexture == nil || theError) {
//            NSLog(@"Error loading file: %@", [theError localizedDescription]);
//        }
//        
//        glBindTexture(spriteTexture.target, spriteTexture.name);
        
    }
    
    void SetBounds(float bottom=-1.0,float top=1.0,float left=-1.0, float right=1.0){
        bounds->SetBounds(bottom,top,left,right);
    }

    ~GraphHelper(){
        
        tearDownGL();
    }
    
    void tearDownGL() {
        
        [EAGLContext setCurrentContext:context];
        
        if( vbo!=nil && color!=nil ){
            for(int k=0;k<numGraphs;k++){
                glDeleteBuffers(1, &vbo[k]);
                glDeleteBuffers(1, &color[k]);
            }
            delete [] vbo;
            delete [] color;
        }
        
        effect = nil;
        
        if(graphs!=nil)
            delete [] graphs;
        if(bounds!=nil)
            delete bounds;
        
        graphs = nil;
        vbo= nil;
        color=nil;
        bounds=nil;
        
    }
    
    

    void update(){
        GLKMatrix4 modelViewMatrix = GLKMatrix4MakeTranslation(0.0f, 0.0f, 0.0f);
        effect.transform.modelviewMatrix = modelViewMatrix;
    }

    void setGraphData(int arrayNum, float *data, int dataLength, float normalization = 1.0, float minValue = 0.0){
        
        if(data==NULL){
            printf("Memory not yet allocated for data buffer\n");
            return;
        }
        
        if(arrayNum>numGraphs){
            printf("tried to access graph number %d, when num graphs initialized is N=%d\n",arrayNum,numGraphs);
            return;
        }
        
        if(dataLength>kGraphMaxSize){
            printf("Request to print more points than allocated for max array size, clipping array length from %d to %d\n",dataLength,kGraphMaxSize);
            dataLength=kGraphMaxSize;
        }
        
        float lengthOverTwo = ((float)dataLength)/2.0; // for plotting the x value
        float xnormalizer = (bounds->width/2.0)/lengthOverTwo;
        float addToPlot = bounds->middle;
        
        normalization -= minValue;
        if(plotStyle == PlotStyleSeparated){
            normalization *= ((float)numGraphs);
            addToPlot = -1 + (((float)arrayNum)) / ((float)numGraphs) * 2 + 1.0/((float)numGraphs);
        }
        
        graphs[arrayNum].graphSize = dataLength;
        
        normalization *= (bounds->height/2.0);
        addToPlot *= (bounds->height/2.0);
        for(int i = 0; i < dataLength; i++) {
            float x = (((float)i) - lengthOverTwo) * xnormalizer;
            graphs[arrayNum].points[i].x = x + bounds->center;
            graphs[arrayNum].points[i].y = (((data[i]-minValue) / normalization) + addToPlot) + bounds->middle;
        }
    }

    void draw(){

        // Clear the view
        glClear(GL_COLOR_BUFFER_BIT);
        
        effect.useConstantColor = GL_FALSE;

        
        [effect prepareToDraw];
        
        
        for(int k=0;k<numGraphs;k++){
            
            glBindBuffer(GL_ARRAY_BUFFER, vbo[k]);
            glBufferData(GL_ARRAY_BUFFER, sizeof(graphs[k].points), graphs[k].points, GL_DYNAMIC_DRAW);
            glEnableVertexAttribArray(GLKVertexAttribPosition);
            glVertexAttribPointer(GLKVertexAttribPosition,   // attribute
                                  2,                   // number of elements per vertex, here (x,y)
                                  GL_FLOAT,            // the type of each element
                                  GL_FALSE,            // take our values as-is
                                  0,                   // no space between values
                                  0                    // use the vertex buffer object
                                  );
            
            // set the color
            glBindBuffer(GL_ARRAY_BUFFER, color[k]);
            //glColorPointer(4, GL_FLOAT, 0, graphs[k].colors);
            glEnableVertexAttribArray(GLKVertexAttribColor);
            glVertexAttribPointer(GLKVertexAttribColor,
                                  4,
                                  GL_FLOAT,
                                  GL_FALSE,
                                  0,
                                  0);

            glDrawArrays(GL_LINE_STRIP, 0, graphs[k].graphSize); // just draw the data that was sent in
            
            glDisableVertexAttribArray(GLKVertexAttribPosition);
            glDisableVertexAttribArray(GLKVertexAttribColor);
        }
        
        
        // uncomment if you need to orphan the data in the buffer to prevent waiting from other threads
        //glBufferData(GL_ARRAY_BUFFER, sizeof(nil), nil, GL_DYNAMIC_DRAW);
        
        //glDisableVertexAttribArray(GLKVertexAttribPosition);
        //glBindBuffer(GL_ARRAY_BUFFER, 0);
        
//		glBindBuffer(GL_ARRAY_BUFFER, vertexTex);
//        glEnableVertexAttribArray(GLKVertexAttribPosition);
//        
//        glVertexAttribPointer(GLKVertexAttribPosition,
//                              2,
//                              GL_FLOAT,
//                              GL_FALSE,
//                              sizeof(Vertices),
//                              (void *) (offsetof(Vertex, Position)));
//        
//        glEnableVertexAttribArray(GLKVertexAttribTexCoord0);
//		glVertexAttribPointer(GLKVertexAttribTexCoord0,
//                              2,
//                              GL_FLOAT,
//                              GL_FALSE,
//                              sizeof(Vertices),
//                              (void *) (offsetof(Vertex, TexCoord)));
//        
//        
//        
//		glDrawArrays(GL_TRIANGLE_STRIP, 0, 3);
//        
//        glDisableVertexAttribArray(GLKVertexAttribPosition);
//        glDisableVertexAttribArray(GLKVertexAttribTexCoord0);
//        glDisableVertexAttribArray(GLKVertexAttribColor);
    }
    
private:
    GraphData *graphs;
    unsigned int numGraphs;
    PlotStyle plotStyle;
    
    GLuint *vbo;
    GLuint *color;
    GLuint vertexTex;
    
    EAGLContext     *context;
    GLKBaseEffect   *effect;
    
    GraphBounds *bounds;
    GLKTextureInfo *spriteTexture;
};

#endif
