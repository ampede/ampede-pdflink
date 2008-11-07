//
//	AmpedePDF.h
//	AmpedePDF
//
//	Created by Erich Ocean on 12/4/06.
//	Copyright Erich Atlas Ocean 2006. All rights reserved.
//

#import "AmpedeGeneratorFxPlug.h"

@interface AmpedePDF : AmpedeGeneratorFxPlug
{
	// The cached API Manager object, as passed to the -initWithAPIManager: method.
	id _apiManager;
    
    IBOutlet NSButton * aboutButton;
    IBOutlet NSButton * optionsButton;
    
    CFMessagePortRef messagePort;
}

- (IBAction) showAboutWindow:   sender;
- (IBAction) showOptionsDialog: sender;

@end