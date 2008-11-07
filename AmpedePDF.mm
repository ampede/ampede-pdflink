//
//	AmpedePDF.mm
//	AmpedePDF
//
//	Created by Erich Ocean on 12/4/06.
//	Copyright Erich Atlas Ocean 2006. All rights reserved.
//

#import "AmpedePDF.h"

#import <FxPlug/FxPlugSDK.h>

#include <OpenGL/gl.h>
#include <OpenGL/glext.h>
#include <OpenGL/glu.h>


static CFMessagePortRef ampedeMsgPort = NULL;

// Parameters
#define kColorParamID 1000

enum {
	ABOUT_BUTTON = 0,
    OPTIONS_BUTTON,
	BASIC_VECTOR_MOTION_TOPIC,
	AMPEDE_SCALE,
	AMPEDE_SCALE_MULTIPLIER,
	AMPEDE_ROTATION,
	AMPEDE_CENTER,
	AMPEDE_ANCHOR_POINT,
	AMPEDE_FORCE_RERENDER,
	AMPEDE_NUM_PARAMS
};

enum {
	SCALE_DISK_ID = 1,
	SCALE_MULTIPLIER_DISK_ID,
	ROTATION_DISK_ID,
	CENTER_DISK_ID,
	ANCHOR_POINT_DISK_ID,
	BASIC_VECTOR_MOTION_TOPIC_DISK_ID,
	FORCE_UPDATE_DISK_ID
};

#define	SCALE_MIN		(1)	
#define	SCALE_MAX		(1000)
#define	SCALE_BIG_MAX	(10000)
#define	SCALE_DFLT		(100)

#define	SCALE_MULTIPLIER_MIN		(0.1)
#define	SCALE_MULTIPLIER_MAX		(10)
#define	SCALE_MULTIPLIER_BIG_MAX	(100)
#define	SCALE_MULTIPLIER_DFLT		(1)

#define	ROTATION_DFLT   (0)

#define CENTER_X_DFLT			(50)
#define CENTER_Y_DFLT			(50)
#define CENTER_RESTRICT_BOUNDS  (0)

#define ANCHOR_POINT_X_DFLT				(50)
#define ANCHOR_POINT_Y_DFLT				(50)
#define ANCHOR_POINT_RESTRICT_BOUNDS	(0)

#define FORCE_UPDATE_DFLT	(0)

//---------------------------------------------------------
// solidcolor
//
// Templated software implementation
//---------------------------------------------------------

template <class PEL> static
void solidcolor( FxBitmap		*outMap,
				double			red,
				double			green,
				double			blue,
				double			alpha,
				PEL				max )
{
	PEL *outData = NULL;
	PEL pelColor[4];
	
	pelColor[0] = (PEL)( alpha * max );
	pelColor[1] = (PEL)( red * max );
	pelColor[2] = (PEL)( green * max );
	pelColor[3] = (PEL)( blue * max );
	
	for ( uint32_t y = 0; y < [outMap height]; ++y )
	{
		outData = (PEL *)[outMap dataPtrForPositionX:0 Y:y];
		
		for ( uint32_t x = 0; x < [outMap width]; ++x )
		{
			*outData++ = pelColor[0];
			*outData++ = pelColor[1];
			*outData++ = pelColor[2];
			*outData++ = pelColor[3];
		}
	}
}

@implementation AmpedePDF

+ (void) initialize
{
    DSINITIALIZE;

    ampedeMsgPort = NULL;
    ampedeMsgPort = CFMessagePortCreateRemote( kCFAllocatorDefault, CFSTR("AmpedeMessagePort") );
        
    if ( ampedeMsgPort )
    {
        CFMessagePortSetInvalidationCallBack( ampedeMsgPort, AmpedeMessagePortInvalidationCallback );
    }
    else NSLog( @"Ampede error: could not communicate with Ampede PDF UI" );
}

#pragma mark -
#pragma mark FxGenerator protocol

//---------------------------------------------------------
// initWithAPIManager:
//
// This method is called when a plug-in is first loaded, and
// is a good point to conduct any checks for anti-piracy or
// system compatibility. Returning NULL means that a plug-in
// chooses not to be accessible for some reason.
//---------------------------------------------------------

- initWithAPIManager: (id) theApiManager
{
    if ( self = [super initWithAPIManager: theApiManager] )
    {
        
    }
    return self;
}

//---------------------------------------------------------
// variesOverTime
//
// This method should return YES if the plug-in's output can
// vary over time even when all of its parameter values remain
// constant. Returning NO means that a rendered frame can be
// cached and reused for other frames with the same parameter
// values.
//---------------------------------------------------------

- (BOOL) variesOverTime
{
	return NO;
}

//---------------------------------------------------------
// properties
//
// This method should return an NSDictionary defining the
// properties of the effect.
//---------------------------------------------------------

- (NSDictionary *) properties
{
    LOG
	return [NSDictionary dictionaryWithObjectsAndKeys:
				[NSNumber numberWithBool: YES], kFxPropertyKey_SupportsRowBytes,
				[NSNumber numberWithBool: NO], kFxPropertyKey_SupportsR408,
				[NSNumber numberWithBool: NO], kFxPropertyKey_SupportsR4fl,
				[NSNumber numberWithBool: NO], kFxPropertyKey_MayRemapTime,
				[NSNumber numberWithInt:0], kFxPropertyKey_EquivalentSMPTEWipeCode,
				NULL];
}

//---------------------------------------------------------
// addParameters
//
// This method is where a plug-in defines its list of parameters.
//---------------------------------------------------------

- (BOOL) addParameters
{   
    LOG
	id parmsApi = [_apiManager apiForProtocol: @protocol( FxParameterCreationAPI )];
	
	if ( parmsApi )
	{
		NSBundle *bundle = [NSBundle bundleForClass: [self class]];
		
		NSString *name = [bundle localizedStringForKey: @"AmpedePDF::About"
								 value:                 NULL
								 table:                 NULL              ];
		
        [parmsApi addCustomParameterWithName: name
                  parmId:                     ABOUT_BUTTON
                  defaultValue:               nil
                  parmFlags:                  kFxParameterFlag_DONT_SAVE      |
                                              kFxParameterFlag_NOT_ANIMATABLE |
                                              kFxParameterFlag_CUSTOM_UI      ];
        
		name = [bundle localizedStringForKey: @"AmpedePDF::Options"
                       value:                 NULL
                       table:                 NULL                ];

        [parmsApi addCustomParameterWithName: name
                  parmId:                     OPTIONS_BUTTON
                  defaultValue:               nil
                  parmFlags:                  kFxParameterFlag_DONT_SAVE      |
                                              kFxParameterFlag_NOT_ANIMATABLE |
                                              kFxParameterFlag_CUSTOM_UI      ];
        
		name = [bundle localizedStringForKey: @"AmpedePDF::Color"
                       value:                 NULL
                       table:                 NULL              ];
		
		[parmsApi addColorParameterWithName: name
                  parmId:                    kColorParamID
                  defaultRed:                0.0
                  defaultGreen:              0.0
                  defaultBlue:               1.0
                  parmFlags:                 kFxParameterFlag_DEFAULT];
                  
        LOG
                  
		return YES;
	}
	else
		return NO;
}

//---------------------------------------------------------
// parameterChanged:
//
// This method will be called whenever a parameter value has changed.
// This provides a plug-in an opportunity to respond by changing the
// value or state of some other parameter.
//---------------------------------------------------------

- (BOOL)
parameterChanged: (UInt32) parmId
{
    // this might be a good place to interact with the remote proxy
	return YES;
}

//---------------------------------------------------------
// frameSetup:hardware:software:
//
// This method will be called before the host app sets up a
// render. A plug-in can indicate here whether it supports
// CPU (software) rendering, GPU (hardware) rendering, or
// both.
//---------------------------------------------------------

- (BOOL)
frameSetup: (FxRenderInfo) renderInfo
hardware:   (BOOL *)       canRenderHardware
software:   (BOOL *)       canRenderSoftware
{
	*canRenderSoftware = YES;
	*canRenderHardware = NO;
	
	return YES;
}

//---------------------------------------------------------
// renderOutput:withInfo:
//
// This method renders the plug-in's output into the given
// destination, with the given render options. The plug-in may
// retrieve parameters as needed here, using the appropriate
// host APIs. The output image will either be an FxBitmap
// or an FxTexture, depending on the plug-in's capabilities,
// as declared in the frameSetup:hardware:software: method.
//---------------------------------------------------------

- (BOOL)
renderOutput: (FxImage *)    outputImage
withInfo:     (FxRenderInfo) renderInfo
{
	BOOL retval = YES;
	id parmsApi	= [_apiManager apiForProtocol:@protocol(FxParameterRetrievalAPI)];
	
	if ( parmsApi != NULL )
	{
		double red, green, blue;
		
		// Get the parm(s)
		[parmsApi getRedValue:&red
				   GreenValue:&green
					BlueValue:&blue
					 fromParm:kColorParamID
					   atTime:renderInfo.frame];
		
		if ( [outputImage imageType] == kFxImageType_TEXTURE )
		{
			double left, right, top, bottom;
			FxTexture *outTex = (FxTexture *)outputImage;
			
			[outTex getTextureCoords:&left
							   right:&right
							  bottom:&bottom
								 top:&top];
			
			glColorMask( GL_TRUE, GL_TRUE, GL_TRUE, GL_TRUE );
			
			glBegin( GL_QUADS );
			
			glColor4f( red, green, blue, 1.0 );
			
			glVertex2f( left, bottom );
			glVertex2f( right, bottom );
			glVertex2f( right, top );
			glVertex2f( left, top );
			
			glEnd();
		}
		else if ( [outputImage imageType] == kFxImageType_BITMAP )
		{
			FxBitmap *outMap = (FxBitmap *)outputImage;
			switch( [outputImage depth] )
			{
				case 8:
					solidcolor( outMap,
								red, 
								green, 
								blue,
								1.0,
								(UInt8)255 );
					break;
				case 16:
					solidcolor( outMap,
								red, 
								green, 
								blue,
								1.0,
								(UInt16)65535 );
					break;
				case 32:
					solidcolor( outMap,
								red, 
								green, 
								blue,
								1.0,
								(float)1.0 );
					break;
			}
		}
		else
			retval = NO;
	}
	else
		retval = NO;
	
	return retval;
}

//---------------------------------------------------------
// frameCleanup
//
// This method is called when the host app is done with a frame.
// A plug-in may release any per-frame retained objects
// at this point.
//---------------------------------------------------------

- (BOOL) frameCleanup
{
	return YES;
}

#pragma mark -
#pragma mark FxCustomParameterViewHost protocol

//---------------------------------------------------------
// FxCustomParameterViewHost protocol implementation
//---------------------------------------------------------

- (NSView *)
createViewForParm: (UInt32) parmId
{
    LOGS
    NSLog( @"parmId is %d", parmId );

    [self loadNibNamed: @"AmpedePDF"];
    
    if ( aboutButton && optionsButton )
    {
        switch ( parmId )
        {
            case ABOUT_BUTTON:
                return [aboutButton retain];
            case OPTIONS_BUTTON:
                return [optionsButton retain];
        }
    }
    else
    {
        NSLog( @"failed to load nib file" );
        return nil;
    }
    
    return nil;
}

#pragma mark -
#pragma mark Interface Builder Actions

- (IBAction) showAboutWindow: sender
{
    LOGS

	int mpErr = 0;

	if ( ampedeMsgPort && CFMessagePortIsValid( ampedeMsgPort ) )
	{
        mpErr = CFMessagePortSendRequest( ampedeMsgPort
                                        , 'INFO'                // XXX this is not valid on Intel
                                        , NULL
                                        , 1.0                   // send timeout in seconds
                                        , 1.0                   // receive timeout in seconds
                                        , kCFRunLoopDefaultMode // run loop reply mode
                                        , NULL
                                        ) ;
        if ( mpErr ) NSLog( @"error with the ABOUT message port send" );
    }
}

- (IBAction) showOptionsDialog: sender
{
    LOGS
	int mpErr = 0;

	if ( messagePort && CFMessagePortIsValid( messagePort ) )
	{
        mpErr = CFMessagePortSendRequest( messagePort
                                        , 'INFO'                // XXX this is not valid on Intel
                                        , NULL
                                        , 1.0                   // send timeout in seconds
                                        , 10.0                  // receive timeout in seconds
                                        , kCFRunLoopDefaultMode // run loop reply mode
                                        , NULL
                                        ) ;
        if ( mpErr ) NSLog( @"error with the OPTIONS message port send" );

        if ( mpErr )
        {
            switch ( mpErr ) {
            
            case kCFMessagePortSendTimeout: break;
            case kCFMessagePortReceiveTimeout: break;
            case kCFMessagePortIsInvalid:
                NSLog( @"Ampede error: kCFMessagePortIsInvalid occured on dialog command" );
                break;

            case kCFMessagePortTransportError:
                NSLog( @"Ampede error: kCFMessagePortTransportError occured on dialog command" );
                break;
            }
        }
    }
}

@end
