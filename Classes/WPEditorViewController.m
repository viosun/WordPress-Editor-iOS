#import "WPEditorViewController.h"
#import "WPEditorViewController_Internal.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import <UIAlertView+Blocks/UIAlertView+Blocks.h>
#import <UIKit/UIKit.h>
#import <WordPressCom-Analytics-iOS/WPAnalytics.h>
#import <WordPress-iOS-Shared/WPFontManager.h>
#import <WordPress-iOS-Shared/WPStyleGuide.h>
#import <WordPress-iOS-Shared/WPTableViewCell.h>
#import <WordPress-iOS-Shared/UIImage+Util.h>
#import <WordPress-iOS-Shared/UIColor+Helpers.h>

#import "WPEditorField.h"
#import "WPEditorToolbarButton.h"
#import "WPEditorView.h"
#import "ZSSBarButtonItem.h"

// Keep an eye on this constant on different iOS versions
static int kToolbarFirstItemExtraPadding = 6;
static int kToolbarItemPadding = 10;
static int kiPodToolbarMarginWidth = 15;
static int kiPhoneSixPlusToolbarMarginWidth = 18;

CGFloat const EPVCStandardOffset = 10.0;
NSInteger const WPImageAlertViewTag = 91;
NSInteger const WPLinkAlertViewTag = 92;

static const CGFloat kWPEditorViewControllerToolbarButtonWidth = 40.0f;
static const CGFloat kWPEditorViewControllerToolbarButtonHeight = 40.0f;
static const CGFloat kWPEditorViewControllerToolbarHeight = 40.0f;

typedef enum
{
	kWPEditorViewControllerElementTagUnknown = -1,
	kWPEditorViewControllerElementTagJustifyLeftBarButton,
	kWPEditorViewControllerElementTagJustifyCenterBarButton,
	kWPEditorViewControllerElementTagJustifyRightBarButton,
	kWPEditorViewControllerElementTagJustifyFullBarButton,
	kWPEditorViewControllerElementTagBackgroundColorBarButton,
	kWPEditorViewControllerElementTagBlockQuoteBarButton,
	kWPEditorViewControllerElementTagBoldBarButton,
	kWPEditorViewControllerElementTagH1BarButton,
	kWPEditorViewControllerElementTagH2BarButton,
	kWPEditorViewControllerElementTagH3BarButton,
	kWPEditorViewControllerElementTagH4BarButton,
	kWPEditorViewControllerElementTagH5BarButton,
	kWPEditorViewControllerElementTagH6BarButton,
	kWPEditorViewControllerElementTagHorizontalRuleBarButton,
	kWPEditorViewControllerElementTagIndentBarButton,
	kWPEditorViewControllerElementTagInsertImageBarButton,
	kWPEditorViewControllerElementTagInsertLinkBarButton,
	kWPEditorViewControllerElementTagItalicBarButton,
	kWPEditorViewControllerElementOrderedListBarButton,
	kWPEditorViewControllerElementOutdentBarButton,
	kWPEditorViewControllerElementQuickLinkBarButton,
	kWPEditorViewControllerElementRedoBarButton,
	kWPEditorViewControllerElementRemoveFormatBarButton,
	kWPEditorViewControllerElementRemoveLinkBarButton,
	kWPEditorViewControllerElementShowSourceBarButton,
	kWPEditorViewControllerElementStrikeThroughBarButton,
	kWPEditorViewControllerElementSubscriptBarButton,
	kWPEditorViewControllerElementSuperscriptBarButton,
	kWPEditorViewControllerElementTextColorBarButton,
	kWPEditorViewControllerElementUnderlineBarButton,
	kWPEditorViewControllerElementUnorderedListBarButton,
	kWPEditorViewControllerElementUndoBarButton,
	
} WPEditorViewControllerElementTag;

@interface WPEditorViewController () <HRColorPickerViewControllerDelegate, UIAlertViewDelegate, WPEditorViewDelegate>

@property (nonatomic, strong) NSString *htmlString;
@property (nonatomic, strong) NSArray *editorItemsEnabled;
@property (nonatomic, strong) UIAlertView *alertView;
@property (nonatomic, strong) NSString *selectedImageURL;
@property (nonatomic, strong) NSString *selectedImageAlt;
@property (nonatomic, strong) NSMutableArray *customBarButtonItems;
@property (nonatomic) BOOL didFinishLoadingEditor;

#pragma mark - Properties: First Setup On View Will Appear
@property (nonatomic, assign, readwrite) BOOL isFirstSetupComplete;

#pragma mark - Properties: Editing
@property (nonatomic, assign, readwrite, getter=isEditingEnabled) BOOL editingEnabled;
@property (nonatomic, assign, readwrite, getter=isEditing) BOOL editing;
@property (nonatomic, assign, readwrite) BOOL wasEditing;

#pragma mark - Properties: Editor View
@property (nonatomic, strong, readwrite) WPEditorView *editorView;

#pragma mark - Properties: Toolbar
@property (nonatomic, strong) UIView *mainToolbarHolder;
@property (nonatomic, weak) UIView *mainToolbarHolderContent;
@property (nonatomic, weak) UIView *mainToolbarHolderTopBorder;
@property (nonatomic, weak) UIToolbar *leftToolbar;
@property (nonatomic, weak) UIToolbar *rightToolbar;
@property (nonatomic, weak) UIView *rightToolbarHolder;
@property (nonatomic, weak) UIScrollView *toolbarScroll;

#pragma mark - Properties: Toolbar items
@property (nonatomic, strong, readwrite) UIBarButtonItem* htmlBarButtonItem;

@end

@implementation WPEditorViewController

#pragma mark - Initializers

- (instancetype)init
{
	return [self initWithMode:kWPEditorViewControllerModeEdit];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
	self = [super initWithCoder:aDecoder];
	
	if (self)
	{
		[self sharedInitializationWithEditing:YES];
	}
	
	return self;
}

- (instancetype)initWithMode:(WPEditorViewControllerMode)mode
{
	self = [super init];
	
	if (self) {
		
		BOOL editing = NO;
		
		if (mode == kWPEditorViewControllerModePreview) {
			editing = NO;
		} else {
			editing = YES;
		}
		
		[self sharedInitializationWithEditing:editing];
	}
	
	return self;
}

#pragma mark - Shared Initialization Code

- (void)sharedInitializationWithEditing:(BOOL)editing
{
	if (editing == kWPEditorViewControllerModePreview) {
		_editing = NO;
	} else {
		_editing = YES;
	}
    
	_toolbarBackgroundColor = [UIColor whiteColor];
    _toolbarBorderColor = [WPStyleGuide readGrey];
    _toolbarItemTintColor = [WPStyleGuide textFieldPlaceholderGrey];
	_toolbarItemSelectedTintColor = [WPStyleGuide baseDarkerBlue];
}

#pragma mark - UIViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	
    // It's important to set this up here, in case the main view of the VC is unloaded due to low
    // memory (it can happen if the view is hidden).
    //
    self.isFirstSetupComplete = NO;
    self.didFinishLoadingEditor = NO;
    self.enabledToolbarItems = [self defaultToolbarItems];
    self.view.backgroundColor = [UIColor whiteColor];
    
    // Calling this here so the Merriweather font is
    // loaded (if it has not been already).
    [WPFontManager merriweatherBoldFontOfSize:30];
	
    [self buildTextViews];
    [self buildToolbar];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
	
    if (!self.isFirstSetupComplete) {
        self.isFirstSetupComplete = YES;

        // When restoring state, the navigationController is nil when the view loads,
        // so configure its appearance here instead.
        self.navigationController.navigationBar.translucent = NO;
        
        for (UIView *view in self.navigationController.toolbar.subviews) {
            [view setExclusiveTouch:YES];
        }
        
        if (self.isEditing) {
            [self startEditing];
        }
    } else {
        [self restoreEditSelection];
    }
    
    [self.navigationController setToolbarHidden:YES animated:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    // It's important to save the edit selection before the view disappears, because as soon as it
    // disappears the first responder is changed.
    //
    [self saveEditSelection];
}

#pragma mark - Default toolbar items

- (ZSSRichTextEditorToolbar)defaultToolbarItems
{
	ZSSRichTextEditorToolbar defaultToolbarItems = (ZSSRichTextEditorToolbarInsertImage
													| ZSSRichTextEditorToolbarBold
													| ZSSRichTextEditorToolbarItalic
													| ZSSRichTextEditorToolbarUnderline
													| ZSSRichTextEditorToolbarInsertLink
													| ZSSRichTextEditorToolbarBlockQuote
                                                    | ZSSRichTextEditorToolbarUnorderedList
													| ZSSRichTextEditorToolbarOrderedList);
	
	// iPad gets the HTML source button too
	if (IS_IPAD) {
		defaultToolbarItems = (defaultToolbarItems
							   | ZSSRichTextEditorToolbarStrikeThrough
							   | ZSSRichTextEditorToolbarViewSource);
	}
	
	return defaultToolbarItems;
}

#pragma mark - Getters

- (UIBarButtonItem*)htmlBarButtonItem
{
	if (!_htmlBarButtonItem) {
		UIBarButtonItem* htmlBarButtonItem =  [[UIBarButtonItem alloc] initWithTitle:@"HTML"
																			   style:UIBarButtonItemStylePlain
																			  target:nil
																			  action:nil];
		
		UIFont * font = [UIFont boldSystemFontOfSize:10];
		NSDictionary * attributes = @{NSFontAttributeName: font};
		[htmlBarButtonItem setTitleTextAttributes:attributes forState:UIControlStateNormal];
		htmlBarButtonItem.accessibilityLabel = NSLocalizedString(@"Display HTML",
																 @"Accessibility label for display HTML button on formatting toolbar.");
		
        CGRect customButtonFrame = CGRectMake(0,
                                              0,
                                              kWPEditorViewControllerToolbarButtonWidth,
                                              kWPEditorViewControllerToolbarButtonHeight);
		
		WPEditorToolbarButton* customButton = [[WPEditorToolbarButton alloc] initWithFrame:customButtonFrame];
		[customButton setTitle:@"HTML" forState:UIControlStateNormal];
		customButton.normalTintColor = self.toolbarItemTintColor;
		customButton.selectedTintColor = self.toolbarItemSelectedTintColor;
		customButton.reversesTitleShadowWhenHighlighted = YES;
		customButton.titleLabel.font = font;
		[customButton addTarget:self
						 action:@selector(showHTMLSource:)
			   forControlEvents:UIControlEventTouchUpInside];
		
		htmlBarButtonItem.customView = customButton;
		
		_htmlBarButtonItem = htmlBarButtonItem;
	}
	
	return _htmlBarButtonItem;
}

- (UIView*)rightToolbarHolder
{
	UIView* rightToolbarHolder = _rightToolbarHolder;
	
	if (!rightToolbarHolder) {
		
		rightToolbarHolder = [[UIView alloc] initWithFrame:CGRectMake(CGRectGetWidth(self.view.frame) - kWPEditorViewControllerToolbarButtonWidth,
																	  0,
																	  kWPEditorViewControllerToolbarButtonWidth,
																	  kWPEditorViewControllerToolbarHeight)];
		rightToolbarHolder.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
		rightToolbarHolder.clipsToBounds = YES;
		
		CGRect toolbarFrame = CGRectMake(0,
										 0,
										 CGRectGetWidth(rightToolbarHolder.frame),
										 CGRectGetHeight(rightToolbarHolder.frame));
		
		UIToolbar *toolbar = [[UIToolbar alloc] initWithFrame:toolbarFrame];
		self.rightToolbar = toolbar;
		
		[rightToolbarHolder addSubview:toolbar];
		
		UIBarButtonItem *negativeSeparator = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace
																						   target:nil
																						   action:nil];
        
        // Negative separator needs to be different on 6+
        if ([self isIPhoneSixPlus]) {
            negativeSeparator.width = -kiPhoneSixPlusToolbarMarginWidth;
        } else {
            negativeSeparator.width = -kiPodToolbarMarginWidth;
        }
		
		toolbar.items = @[negativeSeparator, [self htmlBarButtonItem]];
		toolbar.barTintColor = self.toolbarBackgroundColor;
		
		static const CGFloat kDividerLineWidth = 0.6;
		static const CGFloat kDividerLineHeight = 28;
		
		CGRect dividerLineFrame = CGRectMake(0,
											 floorf((kWPEditorViewControllerToolbarHeight - kDividerLineHeight) / 2),
											 kDividerLineWidth,
											 kDividerLineHeight);
		
		UIView *dividerLine = [[UIView alloc] initWithFrame:dividerLineFrame];
		dividerLine.backgroundColor = self.toolbarBorderColor;
		dividerLine.alpha = 0.7f;
		[rightToolbarHolder addSubview:dividerLine];
	}
	
	return rightToolbarHolder;
}

#pragma mark - Coloring

- (void)setToolbarBackgroundColor:(UIColor *)toolbarBackgroundColor
{
	if (_toolbarBackgroundColor != toolbarBackgroundColor) {
		_toolbarBackgroundColor = toolbarBackgroundColor;
		
		self.mainToolbarHolder.backgroundColor = toolbarBackgroundColor;
		self.leftToolbar.barTintColor = toolbarBackgroundColor;
		self.rightToolbar.barTintColor = toolbarBackgroundColor;
	}
}

- (void)setToolbarBorderColor:(UIColor *)toolbarBorderColor
{
	if (_toolbarBorderColor != toolbarBorderColor) {
		_toolbarBorderColor = toolbarBorderColor;
		
		self.mainToolbarHolderTopBorder.backgroundColor = toolbarBorderColor;
	}
}

- (void)setEnabledToolbarItems:(ZSSRichTextEditorToolbar)enabledToolbarItems
{
    _enabledToolbarItems = enabledToolbarItems;
	
    [self buildToolbar];
}

- (void)setToolbarItemTintColor:(UIColor *)toolbarItemTintColor
{
    _toolbarItemTintColor = toolbarItemTintColor;
    
    // Update the color
    for (UIBarButtonItem *item in self.leftToolbar.items) {
        item.tintColor = [self toolbarItemTintColor];
    }
	
    self.htmlBarButtonItem.tintColor = toolbarItemTintColor;
}

- (void)setToolbarItemSelectedTintColor:(UIColor *)toolbarItemSelectedTintColor
{
    _toolbarItemSelectedTintColor = toolbarItemSelectedTintColor;
}

#pragma mark - Toolbar

- (BOOL)hasSomeEnabledToolbarItems
{
	return !(self.enabledToolbarItems & ZSSRichTextEditorToolbarNone);
}

- (NSMutableArray *)itemsForToolbar
{
    NSMutableArray *items = [[NSMutableArray alloc] init];
	
    if ([self hasSomeEnabledToolbarItems]) {
		if ([self canShowInsertImageBarButton]) {
			[items addObject:[self insertImageBarButton]];
		}
		
		if ([self canShowBoldBarButton]) {
			[items addObject:[self boldBarButton]];
		}
		
		if ([self canShowItalicBarButton]) {
			[items addObject:[self italicBarButton]];
		}
		
		if ([self canShowSubscriptBarButton]) {
			[items addObject:[self subscriptBarButton]];
		}
		
		if ([self canShowSuperscriptBarButton]) {
			[items addObject:[self superscriptBarButton]];
		}
		
		if ([self canShowStrikeThroughBarButton]) {
			[items addObject:[self strikeThroughBarButton]];
		}
		
		if ([self canShowUnderlineBarButton]) {
			[items addObject:[self underlineBarButton]];
		}
		
		if ([self canShowBlockQuoteBarButton]) {
			[items addObject:[self blockQuoteBarButton]];
		}
		
		if ([self canShowRemoveFormatBarButton]) {
			[items addObject:[self removeFormatBarButton]];
		}
		
		if ([self canShowUndoBarButton]) {
			[items addObject:[self undoBarButton]];
		}
		
		if ([self canShowRedoBarButton]) {
			[items addObject:[self redoBarButton]];
		}
		
		if ([self canShowAlignLeftBarButton]) {
			[items addObject:[self alignLeftBarButton]];
		}
		
		if ([self canShowAlignCenterBarButton]) {
			[items addObject:[self alignCenterBarButton]];
		}
		
		if ([self canShowAlignRightBarButton]) {
			[items addObject:[self alignRightBarButton]];
		}
		
		if ([self canShowAlignFullBarButton]) {
			[items addObject:[self alignFullBarButton]];
		}
		
		if ([self canShowHeader1BarButton]) {
			[items addObject:[self header1BarButton]];
		}
		
		if ([self canShowHeader2BarButton]) {
			[items addObject:[self header2BarButton]];
		}
		
		if ([self canShowHeader3BarButton]) {
			[items addObject:[self header3BarButton]];
		}
		
		if ([self canShowHeader4BarButton]) {
			[items addObject:[self header4BarButton]];
		}
		
		if ([self canShowHeader5BarButton]) {
			[items addObject:[self header5BarButton]];
		}
		
		if ([self canShowHeader6BarButton]) {
			[items addObject:[self header6BarButton]];
		}
		
		if ([self canShowTextColorBarButton]) {
			[items addObject:[self textColorBarButton]];
		}
		
		if ([self canShowBackgroundColorBarButton]) {
			[items addObject:[self backgroundColorBarButton]];
		}
		
		if ([self canShowUnorderedListBarButton]) {
			[items addObject:[self unorderedListBarButton]];
		}
		
		if ([self canShowOrderedListBarButton]) {
			[items addObject:[self orderedListBarButton]];
		}
		
		if ([self canShowHorizontalRuleBarButton]) {
			[items addObject:[self horizontalRuleBarButton]];
		}
		
		if ([self canShowIndentBarButton]) {
			[items addObject:[self indentBarButton]];
		}
		
		if ([self canShowOutdentBarButton]) {
			[items addObject:[self outdentBarButton]];
		}
		
		if ([self canShowInsertLinkBarButton]) {
			[items addObject:[self inserLinkBarButton]];
		}
		
		if ([self canShowRemoveLinkBarButton]) {
			[items addObject:[self removeLinkBarButton]];
		}
		
		if ([self canShowQuickLinkBarButton]) {
			[items addObject:[self quickLinkBarButton]];
		}
		
		if ([self canShowSourceBarButton]) {
			[items addObject:[self showSourceBarButton]];
		}
	}
		
	return items;
}

#pragma mark - Toolbar: helper methods

- (BOOL)canShowToolbarOption:(ZSSRichTextEditorToolbar)toolbarOption
{
	return (self.enabledToolbarItems & toolbarOption
			|| self.enabledToolbarItems & ZSSRichTextEditorToolbarAll);
}

- (BOOL)canShowAlignLeftBarButton
{
	return [self canShowToolbarOption:ZSSRichTextEditorToolbarJustifyLeft];
}

- (BOOL)canShowAlignCenterBarButton
{
	return [self canShowToolbarOption:ZSSRichTextEditorToolbarJustifyCenter];
}

- (BOOL)canShowAlignFullBarButton
{
	return [self canShowToolbarOption:ZSSRichTextEditorToolbarJustifyFull];
}

- (BOOL)canShowAlignRightBarButton
{
	return [self canShowToolbarOption:ZSSRichTextEditorToolbarJustifyRight];
}

- (BOOL)canShowBackgroundColorBarButton
{
	return [self canShowToolbarOption:ZSSRichTextEditorToolbarBackgroundColor];
}

- (BOOL)canShowBlockQuoteBarButton
{
	return [self canShowToolbarOption:ZSSRichTextEditorToolbarBlockQuote];
}

- (BOOL)canShowBoldBarButton
{
	return [self canShowToolbarOption:ZSSRichTextEditorToolbarBold];
}

- (BOOL)canShowHeader1BarButton
{
	return [self canShowToolbarOption:ZSSRichTextEditorToolbarH1];
}

- (BOOL)canShowHeader2BarButton
{
	return [self canShowToolbarOption:ZSSRichTextEditorToolbarH2];
}

- (BOOL)canShowHeader3BarButton
{
	return [self canShowToolbarOption:ZSSRichTextEditorToolbarH3];
}

- (BOOL)canShowHeader4BarButton
{
	return [self canShowToolbarOption:ZSSRichTextEditorToolbarH4];
}

- (BOOL)canShowHeader5BarButton
{
	return [self canShowToolbarOption:ZSSRichTextEditorToolbarH5];
}

- (BOOL)canShowHeader6BarButton
{
	return [self canShowToolbarOption:ZSSRichTextEditorToolbarH6];
}

- (BOOL)canShowHorizontalRuleBarButton
{
	return [self canShowToolbarOption:ZSSRichTextEditorToolbarHorizontalRule];
}

- (BOOL)canShowIndentBarButton
{
	return [self canShowToolbarOption:ZSSRichTextEditorToolbarIndent];
}

- (BOOL)canShowInsertImageBarButton
{
	return [self canShowToolbarOption:ZSSRichTextEditorToolbarInsertImage];
}

- (BOOL)canShowInsertLinkBarButton
{
	return [self canShowToolbarOption:ZSSRichTextEditorToolbarInsertLink];
}

- (BOOL)canShowItalicBarButton
{
	return [self canShowToolbarOption:ZSSRichTextEditorToolbarItalic];
}

- (BOOL)canShowOrderedListBarButton
{
	return [self canShowToolbarOption:ZSSRichTextEditorToolbarOrderedList];
}

- (BOOL)canShowOutdentBarButton
{
	return [self canShowToolbarOption:ZSSRichTextEditorToolbarOutdent];
}

- (BOOL)canShowQuickLinkBarButton
{
	return [self canShowToolbarOption:ZSSRichTextEditorToolbarQuickLink];
}

- (BOOL)canShowRedoBarButton
{
	return [self canShowToolbarOption:ZSSRichTextEditorToolbarRedo];
}

- (BOOL)canShowRemoveFormatBarButton
{
	return [self canShowToolbarOption:ZSSRichTextEditorToolbarRemoveFormat];
}

- (BOOL)canShowRemoveLinkBarButton
{
	return [self canShowToolbarOption:ZSSRichTextEditorToolbarRemoveLink];
}

- (BOOL)canShowSourceBarButton
{
	return [self canShowToolbarOption:ZSSRichTextEditorToolbarViewSource];
}

- (BOOL)canShowStrikeThroughBarButton
{
	return [self canShowToolbarOption:ZSSRichTextEditorToolbarStrikeThrough];
}

- (BOOL)canShowSubscriptBarButton
{
	return [self canShowToolbarOption:ZSSRichTextEditorToolbarSubscript];
}

- (BOOL)canShowSuperscriptBarButton
{
	return [self canShowToolbarOption:ZSSRichTextEditorToolbarSuperscript];
}

- (BOOL)canShowTextColorBarButton
{
	return [self canShowToolbarOption:ZSSRichTextEditorToolbarTextColor];
}

- (BOOL)canShowUnderlineBarButton
{
	return [self canShowToolbarOption:ZSSRichTextEditorToolbarUnderline];
}

- (BOOL)canShowUndoBarButton
{
	return [self canShowToolbarOption:ZSSRichTextEditorToolbarUndo];
}

- (BOOL)canShowUnorderedListBarButton
{
	return [self canShowToolbarOption:ZSSRichTextEditorToolbarUnorderedList];
}

#pragma mark - Toolbar: buttons

- (ZSSBarButtonItem*)barButtonItemWithTag:(WPEditorViewControllerElementTag)tag
							 htmlProperty:(NSString*)htmlProperty
								imageName:(NSString*)imageName
								   target:(id)target
								 selector:(SEL)selector
					   accessibilityLabel:(NSString*)accessibilityLabel
{
	ZSSBarButtonItem *barButtonItem = [[ZSSBarButtonItem alloc] initWithImage:nil
																		style:UIBarButtonItemStylePlain
																	   target:nil
																	   action:nil];
	barButtonItem.tag = tag;
	barButtonItem.htmlProperty = htmlProperty;
	barButtonItem.accessibilityLabel = accessibilityLabel;

	UIImage* buttonImage = [[UIImage imageNamed:imageName] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];

	WPEditorToolbarButton* customButton = [[WPEditorToolbarButton alloc] initWithFrame:CGRectMake(0,
																								  0,
																								  kWPEditorViewControllerToolbarButtonWidth,
																								  kWPEditorViewControllerToolbarButtonHeight)];
	[customButton setImage:buttonImage forState:UIControlStateNormal];
	customButton.normalTintColor = self.toolbarItemTintColor;
	customButton.selectedTintColor = self.toolbarItemSelectedTintColor;
	[customButton addTarget:self
					 action:selector
		   forControlEvents:UIControlEventTouchUpInside];
	barButtonItem.customView = customButton;
	
	return barButtonItem;
}

- (ZSSBarButtonItem*)alignLeftBarButton
{
	ZSSBarButtonItem *barButtonItem = [self barButtonItemWithTag:kWPEditorViewControllerElementTagJustifyLeftBarButton
													htmlProperty:@"justifyLeft"
													   imageName:@"ZSSleftjustify.png"
														  target:self
														selector:@selector(alignLeft)
											  accessibilityLabel:nil];
	
	return barButtonItem;
}

- (UIBarButtonItem*)alignCenterBarButton
{
	ZSSBarButtonItem *barButtonItem = [self barButtonItemWithTag:kWPEditorViewControllerElementTagJustifyCenterBarButton
													htmlProperty:@"justifyCenter"
													   imageName:@"ZSScenterjustify.png"
														  target:self
														selector:@selector(alignCenter)
											  accessibilityLabel:nil];
	
	return barButtonItem;
}

- (UIBarButtonItem*)alignFullBarButton
{
	ZSSBarButtonItem *barButtonItem = [self barButtonItemWithTag:kWPEditorViewControllerElementTagJustifyFullBarButton
													htmlProperty:@"justifyFull"
													   imageName:@"ZSSforcejustify.png"
														  target:self
														selector:@selector(alignFull)
											  accessibilityLabel:nil];
	
	return barButtonItem;
}

- (UIBarButtonItem*)alignRightBarButton
{
	ZSSBarButtonItem *barButtonItem = [self barButtonItemWithTag:kWPEditorViewControllerElementTagJustifyRightBarButton
													htmlProperty:@"justifyRight"
													   imageName:@"ZSSrightjustify.png"
														  target:self
														selector:@selector(alignRight)
											  accessibilityLabel:nil];
	
	return barButtonItem;
}

- (UIBarButtonItem*)backgroundColorBarButton
{
	ZSSBarButtonItem *barButtonItem = [self barButtonItemWithTag:kWPEditorViewControllerElementTagBackgroundColorBarButton
													htmlProperty:@"backgroundColor"
													   imageName:@"ZSSbgcolor.png"
														  target:self
														selector:@selector(bgColor)
											  accessibilityLabel:nil];
	
	return barButtonItem;
}

- (UIBarButtonItem*)blockQuoteBarButton
{
	NSString* accessibilityLabel = NSLocalizedString(@"Block Quote",
													 @"Accessibility label for block quote button on formatting toolbar.");
	
	ZSSBarButtonItem *barButtonItem = [self barButtonItemWithTag:kWPEditorViewControllerElementTagBlockQuoteBarButton
													htmlProperty:@"blockquote"
													   imageName:@"icon_format_quote"
														  target:self
														selector:@selector(setBlockQuote)
											  accessibilityLabel:accessibilityLabel];
	
	return barButtonItem;
}

- (UIBarButtonItem*)boldBarButton
{
	NSString* accessibilityLabel = NSLocalizedString(@"Bold",
													 @"Accessibility label for bold button on formatting toolbar.");
	
	ZSSBarButtonItem *barButtonItem = [self barButtonItemWithTag:kWPEditorViewControllerElementTagBoldBarButton
													htmlProperty:@"bold"
													   imageName:@"icon_format_bold"
														  target:self
														selector:@selector(setBold)
											  accessibilityLabel:accessibilityLabel];
	
	return barButtonItem;
}

- (UIBarButtonItem*)header1BarButton
{
	ZSSBarButtonItem *barButtonItem = [self barButtonItemWithTag:kWPEditorViewControllerElementTagH1BarButton
													htmlProperty:@"h1"
													   imageName:@"ZSSh1.png"
														  target:self
														selector:@selector(heading1)
											  accessibilityLabel:nil];
	
	return barButtonItem;
}

- (UIBarButtonItem*)header2BarButton
{
	ZSSBarButtonItem *barButtonItem = [self barButtonItemWithTag:kWPEditorViewControllerElementTagH2BarButton
													htmlProperty:@"h2"
													   imageName:@"ZSSh2.png"
														  target:self
														selector:@selector(heading2)
											  accessibilityLabel:nil];
	
	return barButtonItem;
}

- (UIBarButtonItem*)header3BarButton
{
	ZSSBarButtonItem *barButtonItem = [self barButtonItemWithTag:kWPEditorViewControllerElementTagH3BarButton
													htmlProperty:@"h3"
													   imageName:@"ZSSh3.png"
														  target:self
														selector:@selector(heading3)
											  accessibilityLabel:nil];
	
	return barButtonItem;
}

- (UIBarButtonItem*)header4BarButton
{
	ZSSBarButtonItem *barButtonItem = [self barButtonItemWithTag:kWPEditorViewControllerElementTagH4BarButton
													htmlProperty:@"h4"
													   imageName:@"ZSSh4.png"
														  target:self
														selector:@selector(heading4)
											  accessibilityLabel:nil];
	
	return barButtonItem;
}

- (UIBarButtonItem*)header5BarButton
{
	ZSSBarButtonItem *barButtonItem = [self barButtonItemWithTag:kWPEditorViewControllerElementTagH5BarButton
													htmlProperty:@"h5"
													   imageName:@"ZSSh5.png"
														  target:self
														selector:@selector(heading5)
											  accessibilityLabel:nil];
	
	return barButtonItem;
}

- (UIBarButtonItem*)header6BarButton
{
	ZSSBarButtonItem *barButtonItem = [self barButtonItemWithTag:kWPEditorViewControllerElementTagH6BarButton
													htmlProperty:@"h6"
													   imageName:@"ZSSh6.png"
														  target:self
														selector:@selector(heading6)
											  accessibilityLabel:nil];
	
	return barButtonItem;
}
		
- (UIBarButtonItem*)horizontalRuleBarButton
{
	ZSSBarButtonItem *barButtonItem = [self barButtonItemWithTag:kWPEditorViewControllerElementTagHorizontalRuleBarButton
													htmlProperty:@"horizontalRule"
													   imageName:@"ZSShorizontalrule.png"
														  target:self
														selector:@selector(setHR)
											  accessibilityLabel:nil];
	
	return barButtonItem;
}

- (UIBarButtonItem*)indentBarButton
{
	ZSSBarButtonItem *barButtonItem = [self barButtonItemWithTag:kWPEditorViewControllerElementTagIndentBarButton
													htmlProperty:@"indent"
													   imageName:@"ZSSindent.png"
														  target:self
														selector:@selector(setIndent)
											  accessibilityLabel:nil];
	
	return barButtonItem;
}

- (UIBarButtonItem*)insertImageBarButton
{
	NSString* accessibilityLabel = NSLocalizedString(@"Insert Image",
													 @"Accessibility label for insert image button on formatting toolbar.");
	
	ZSSBarButtonItem *barButtonItem = [self barButtonItemWithTag:kWPEditorViewControllerElementTagInsertImageBarButton
													htmlProperty:@"image"
													   imageName:@"icon_media"
														  target:self
														selector:@selector(didTouchMediaOptions)
											  accessibilityLabel:accessibilityLabel];
	
	return barButtonItem;
}

- (UIBarButtonItem*)inserLinkBarButton
{
	NSString* accessibilityLabel = NSLocalizedString(@"Insert Link",
													 @"Accessibility label for insert link button on formatting toolbar.");
	
	ZSSBarButtonItem *barButtonItem = [self barButtonItemWithTag:kWPEditorViewControllerElementTagInsertLinkBarButton
													htmlProperty:@"link"
													   imageName:@"icon_format_link"
														  target:self
														selector:@selector(linkBarButtonTapped:)
											  accessibilityLabel:accessibilityLabel];
	
	return barButtonItem;
}

- (UIBarButtonItem*)italicBarButton
{
	NSString* accessibilityLabel = NSLocalizedString(@"Italic",
													 @"Accessibility label for italic button on formatting toolbar.");
	
	ZSSBarButtonItem *barButtonItem = [self barButtonItemWithTag:kWPEditorViewControllerElementTagItalicBarButton
													htmlProperty:@"italic"
													   imageName:@"icon_format_italic"
														  target:self
														selector:@selector(setItalic)
											  accessibilityLabel:accessibilityLabel];
	
	return barButtonItem;
}

- (UIBarButtonItem*)orderedListBarButton
{
	NSString* accessibilityLabel = NSLocalizedString(@"Ordered List",
													 @"Accessibility label for ordered list button on formatting toolbar.");;
	
	ZSSBarButtonItem *barButtonItem = [self barButtonItemWithTag:kWPEditorViewControllerElementOrderedListBarButton
													htmlProperty:@"orderedList"
													   imageName:@"icon_format_ol"
														  target:self
														selector:@selector(setOrderedList)
											  accessibilityLabel:accessibilityLabel];
	
	return barButtonItem;
}

- (UIBarButtonItem*)outdentBarButton
{
	ZSSBarButtonItem *barButtonItem = [self barButtonItemWithTag:kWPEditorViewControllerElementOutdentBarButton
													htmlProperty:@"outdent"
													   imageName:@"ZSSoutdent.png"
														  target:self
														selector:@selector(setOutdent)
											  accessibilityLabel:nil];
	
	return barButtonItem;
}

- (UIBarButtonItem*)quickLinkBarButton
{
	ZSSBarButtonItem *barButtonItem = [self barButtonItemWithTag:kWPEditorViewControllerElementQuickLinkBarButton
													htmlProperty:@"quickLink"
													   imageName:@"ZSSquicklink.png"
														  target:self
														selector:@selector(quickLink)
											  accessibilityLabel:nil];
	
	return barButtonItem;
}

- (UIBarButtonItem*)redoBarButton
{
	ZSSBarButtonItem *barButtonItem = [self barButtonItemWithTag:kWPEditorViewControllerElementRedoBarButton
												  htmlProperty:@"redo"
													 imageName:@"ZSSredo.png"
														target:self
														selector:@selector(redo:)
											accessibilityLabel:nil];
	
	return barButtonItem;
}

- (UIBarButtonItem*)removeFormatBarButton
{
	ZSSBarButtonItem *barButtonItem = [self barButtonItemWithTag:kWPEditorViewControllerElementRemoveFormatBarButton
													htmlProperty:@"removeFormat"
													   imageName:@"ZSSclearstyle.png"
														  target:self
														selector:@selector(removeFormat)
											  accessibilityLabel:nil];
	
	return barButtonItem;
}

- (UIBarButtonItem*)removeLinkBarButton
{
	NSString* accessibilityLabel = NSLocalizedString(@"Remove Link",
													 @"Accessibility label for remove link button on formatting toolbar.");
	
	ZSSBarButtonItem *barButtonItem = [self barButtonItemWithTag:kWPEditorViewControllerElementRemoveFormatBarButton
													htmlProperty:@"link"
													   imageName:@"icon_format_unlink"
														  target:self
														selector:@selector(removeLink)
											  accessibilityLabel:accessibilityLabel];
	
	return barButtonItem;
}

- (UIBarButtonItem*)showSourceBarButton
{
    NSString* accessibilityLabel = NSLocalizedString(@"HTML",
                                                     @"Accessibility label for HTML button on formatting toolbar.");
    
    ZSSBarButtonItem *barButtonItem = [self barButtonItemWithTag:kWPEditorViewControllerElementShowSourceBarButton
													htmlProperty:@"source"
													   imageName:@"icon_format_html"
														  target:self
														selector:@selector(showHTMLSource:)
											  accessibilityLabel:accessibilityLabel];
	
	return barButtonItem;
}

- (UIBarButtonItem*)strikeThroughBarButton
{
	NSString* accessibilityLabel = NSLocalizedString(@"Strike Through",
													 @"Accessibility label for strikethrough button on formatting toolbar.");
	
	ZSSBarButtonItem *barButtonItem = [self barButtonItemWithTag:kWPEditorViewControllerElementStrikeThroughBarButton
													htmlProperty:@"strikeThrough"
													   imageName:@"icon_format_strikethrough"
														  target:self
														selector:@selector(setStrikethrough)
											  accessibilityLabel:accessibilityLabel];
	
	return barButtonItem;
}

- (UIBarButtonItem*)subscriptBarButton
{
	ZSSBarButtonItem *barButtonItem = [self barButtonItemWithTag:kWPEditorViewControllerElementSubscriptBarButton
													htmlProperty:@"subscript"
													   imageName:@"ZSSsubscript.png"
														  target:self
														selector:@selector(setSubscript)
											  accessibilityLabel:nil];
	
	return barButtonItem;
}

- (UIBarButtonItem*)superscriptBarButton
{
	ZSSBarButtonItem *barButtonItem = [self barButtonItemWithTag:kWPEditorViewControllerElementSuperscriptBarButton
													htmlProperty:@"superscript"
													   imageName:@"ZSSsuperscript.png"
														  target:self
														selector:@selector(setSuperscript)
											  accessibilityLabel:nil];
	
	return barButtonItem;
}

- (UIBarButtonItem*)textColorBarButton
{
	ZSSBarButtonItem *barButtonItem = [self barButtonItemWithTag:kWPEditorViewControllerElementTextColorBarButton
													htmlProperty:@"textColor"
													   imageName:@"ZSStextcolor.png"
														  target:self
														selector:@selector(textColor)
											  accessibilityLabel:nil];
	
	return barButtonItem;
}

- (UIBarButtonItem*)underlineBarButton
{
	NSString* accessibilityLabel = NSLocalizedString(@"Underline",
													 @"Accessibility label for underline button on formatting toolbar.");
	
	ZSSBarButtonItem *barButtonItem = [self barButtonItemWithTag:kWPEditorViewControllerElementUnderlineBarButton
													htmlProperty:@"underline"
													   imageName:@"icon_format_underline"
														  target:self
														selector:@selector(setUnderline)
											  accessibilityLabel:accessibilityLabel];
	
	return barButtonItem;
}

- (UIBarButtonItem*)unorderedListBarButton
{
	NSString* accessibilityLabel = NSLocalizedString(@"Unordered List",
													 @"Accessibility label for unordered list button on formatting toolbar.");
	
	ZSSBarButtonItem *barButtonItem = [self barButtonItemWithTag:kWPEditorViewControllerElementUnorderedListBarButton
													htmlProperty:@"unorderedList"
													   imageName:@"icon_format_ul"
														  target:self
														selector:@selector(setUnorderedList)
											  accessibilityLabel:accessibilityLabel];
	
	return barButtonItem;
}

- (UIBarButtonItem*)undoBarButton
{
	ZSSBarButtonItem *barButtonItem = [self barButtonItemWithTag:kWPEditorViewControllerElementUndoBarButton
													htmlProperty:@"undo"
													   imageName:@"ZSSundo.png"
														  target:self
														selector:@selector(undo:)
											  accessibilityLabel:nil];
	
	return barButtonItem;
}

#pragma mark - Builders

- (void)buildToolbar
{
	if (!self.mainToolbarHolder) {
		[self buildMainToolbarHolder];
	}
	
    if (!self.toolbarScroll) {
		[self buildToolbarScroll];
    }
    
    if (!self.leftToolbar) {
		[self buildLeftToolbar];
    }
	
    if (!IS_IPAD) {
        [self.mainToolbarHolderContent addSubview:[self rightToolbarHolder]];
    }
    
    // Check to see if we have any toolbar items, if not, add them all
    NSMutableArray *items = [self itemsForToolbar];
    if (items.count == 0 && !(_enabledToolbarItems & ZSSRichTextEditorToolbarNone)) {
        _enabledToolbarItems = ZSSRichTextEditorToolbarAll;
        items = [self itemsForToolbar];
	}
	
	CGFloat toolbarWidth = items.count == 0 ? 0.0f : kToolbarFirstItemExtraPadding + (CGFloat)(items.count * kWPEditorViewControllerToolbarButtonWidth);
	
    if (self.customBarButtonItems != nil)
    {
		[items addObjectsFromArray:self.customBarButtonItems];
		
        for(UIBarButtonItem *buttonItem in self.customBarButtonItems)
        {
            toolbarWidth += buttonItem.customView.frame.size.width + 11.0f;
        }
    }
	
	UIBarButtonItem *negativeSeparator = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace
																					   target:nil
																					   action:nil];
	negativeSeparator.width = -kToolbarItemPadding;
	
	// This code adds a negative separator between all the toolbar buttons
	//
	for (NSInteger i = [items count]; i >= 0; i--) {
		[items insertObject:negativeSeparator atIndex:i];
	}
	
    self.leftToolbar.items = items;
    self.leftToolbar.frame = CGRectMake(0,
										0,
										toolbarWidth,
										kWPEditorViewControllerToolbarHeight);
    self.toolbarScroll.contentSize = CGSizeMake(CGRectGetWidth(self.leftToolbar.frame),
												kWPEditorViewControllerToolbarHeight);
}

- (void)buildLeftToolbar
{
	NSAssert(!self.leftToolbar, @"This is supposed to be called only once.");
	
	UIToolbar* leftToolbar = [[UIToolbar alloc] initWithFrame:CGRectZero];
	leftToolbar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	leftToolbar.barTintColor = [self toolbarBackgroundColor];
	leftToolbar.translucent = NO;
	
	[self.toolbarScroll addSubview:leftToolbar];
	self.leftToolbar = leftToolbar;
}

- (void)buildMainToolbarHolder
{
	NSAssert(!self.mainToolbarHolder, @"This is supposed to be called only once.");
	
	UIView* mainToolbarHolder = [[UIView alloc] initWithFrame:CGRectMake(0,
																		 CGRectGetHeight(self.view.frame),
																		 CGRectGetWidth(self.view.frame),
																		 kWPEditorViewControllerToolbarHeight)];
	mainToolbarHolder.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	mainToolbarHolder.backgroundColor = self.toolbarBackgroundColor;
	
	CGRect subviewFrame = mainToolbarHolder.frame;
	subviewFrame.origin = CGPointZero;
	
	UIView* mainToolbarHolderContent = [[UIView alloc] initWithFrame:subviewFrame];
    mainToolbarHolderContent.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	
    subviewFrame.size.height = 1.0f;
	
    UIView* mainToolbarHolderTopBorder = [[UIView alloc] initWithFrame:subviewFrame];
    mainToolbarHolderTopBorder.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	mainToolbarHolderTopBorder.backgroundColor = self.toolbarBorderColor;
	
	[mainToolbarHolder addSubview:mainToolbarHolderContent];
	[mainToolbarHolder addSubview:mainToolbarHolderTopBorder];
	
	self.mainToolbarHolder = mainToolbarHolder;
	self.mainToolbarHolderContent = mainToolbarHolderContent;
	self.mainToolbarHolderTopBorder = mainToolbarHolderTopBorder;
}

- (void)buildTextViews
{
    if (!self.editorView) {
        CGFloat viewWidth = CGRectGetWidth(self.view.frame);
        UIViewAutoresizing mask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        
        CGRect frame = CGRectMake(0.0f, 0.0f, viewWidth, CGRectGetHeight(self.view.frame));
        
        self.editorView = [[WPEditorView alloc] initWithFrame:frame];
        self.editorView.delegate = self;
        self.editorView.autoresizesSubviews = YES;
        self.editorView.autoresizingMask = mask;
        self.editorView.backgroundColor = [UIColor whiteColor];
        self.editorView.sourceView.inputAccessoryView = self.mainToolbarHolder;
    }
	
    [self.view addSubview:self.editorView];
}

- (void)buildToolbarScroll
{
	NSAssert(!self.toolbarScroll, @"This is supposed to be called only once.");
	
	CGFloat scrollviewHeight = CGRectGetWidth(self.view.frame);
 
	if (!IS_IPAD) {
		scrollviewHeight -= kWPEditorViewControllerToolbarButtonWidth;
	}
	
	CGRect toolbarScrollFrame = CGRectMake(0,
										   0,
										   scrollviewHeight,
										   kWPEditorViewControllerToolbarHeight);
	
	UIScrollView* toolbarScroll = [[UIScrollView alloc] initWithFrame:toolbarScrollFrame];
	toolbarScroll.showsHorizontalScrollIndicator = NO;
	toolbarScroll.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	
	[self.mainToolbarHolderContent addSubview:toolbarScroll];
	self.toolbarScroll = toolbarScroll;
}

#pragma mark - Getters and Setters

- (NSString*)titleText
{
    return [self.editorView.titleField html];
}

- (void)setTitleText:(NSString*)titleText
{
    [self.editorView.titleField setHtml:titleText];
}

- (NSString*)bodyText
{
    return [self.editorView.contentField html];
}

- (void)setBodyText:(NSString*)bodyText
{
    [self.editorView.contentField setHtml:bodyText];
}

#pragma mark - Actions

- (void)didTouchMediaOptions
{
    if ([self.delegate respondsToSelector: @selector(editorDidPressMedia:)]) {
        [self.delegate editorDidPressMedia:self];
    }
    [WPAnalytics track:WPAnalyticsStatEditorTappedImage];
}

#pragma mark - Editor and Misc Methods

- (BOOL)isBodyTextEmpty
{
    if(!self.bodyText
       || self.bodyText.length == 0
       || [[self.bodyText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] isEqualToString:@""]
       || [[self.bodyText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] isEqualToString:@"<br>"]
       || [[self.bodyText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] isEqualToString:@"<br />"]) {
        return YES;
    }
    return NO;
}

#pragma mark - Editing

/**
 *	@brief		Enables editing.
 */
- (void)enableEditing
{
	self.editingEnabled = YES;
	
	if (self.didFinishLoadingEditor)
	{
		[self.editorView enableEditing];
	}
}

/**
 *	@brief		Disables editing.
 */
- (void)disableEditing
{
	self.editingEnabled = NO;
	
	if (self.didFinishLoadingEditor)
	{
		[self.editorView disableEditing];
	}
}

/**
 *  @brief      Restored the previously saved edit selection.
 *  @details    Will only really do anything if editing is enabled.
 */
- (void)restoreEditSelection
{
    if (self.isEditing) {
        [self.editorView restoreSelection];
    }
}

/**
 *  @brief      Saves the current edit selection, if any.
 */
- (void)saveEditSelection
{
    if (self.isEditing) {
        [self.editorView saveSelection];
    }
}

- (void)startEditing
{
	self.editing = YES;
	
	// We need the editor ready before executing the steps in the conditional block below.
	// If it's not ready, this method will be called again on webViewDidFinishLoad:
	//
	if (self.didFinishLoadingEditor)
	{
        [self enableEditing];
		[self tellOurDelegateEditingDidBegin];
	}
}

- (void)stopEditing
{
	self.editing = NO;
	
	[self disableEditing];
	[self tellOurDelegateEditingDidEnd];
}

#pragma mark - Editor Interaction

- (void)showHTMLSource:(UIBarButtonItem *)barButtonItem
{	
    if ([self.editorView isInVisualMode]) {
		[self.editorView showHTMLSource];
		
        barButtonItem.tintColor = [self barButtonItemSelectedDefaultColor];
    } else {
		[self.editorView showVisualEditor];
		
        barButtonItem.tintColor = [self toolbarItemTintColor];
    }
    
    [WPAnalytics track:WPAnalyticsStatEditorTappedHTML];
}

- (void)removeFormat
{
    [self.editorView removeFormat];
}

- (void)alignLeft
{
    [self.editorView alignLeft];
}

- (void)alignCenter
{
    [self.editorView alignCenter];
}

- (void)alignRight
{
    [self.editorView alignRight];
}

- (void)alignFull
{
    [self.editorView alignFull];
}

- (void)setBold
{
    [self.editorView setBold];
    [WPAnalytics track:WPAnalyticsStatEditorTappedBold];
}

- (void)setBlockQuote
{
    [self.editorView setBlockQuote];
    [WPAnalytics track:WPAnalyticsStatEditorTappedBlockquote];
}

- (void)setItalic
{
    [self.editorView setItalic];
    [WPAnalytics track:WPAnalyticsStatEditorTappedItalic];
}

- (void)setSubscript
{
    [self.editorView setSubscript];
}

- (void)setUnderline
{
	[self.editorView setUnderline];
    [WPAnalytics track:WPAnalyticsStatEditorTappedUnderline];
}

- (void)setSuperscript
{
	[self.editorView setSuperscript];
}

- (void)setStrikethrough
{
    [self.editorView setStrikethrough];
    [WPAnalytics track:WPAnalyticsStatEditorTappedStrikethrough];
}

- (void)setUnorderedList
{
    [self.editorView setUnorderedList];
    [WPAnalytics track:WPAnalyticsStatEditorTappedUnorderedList];
}

- (void)setOrderedList
{
    [self.editorView setOrderedList];
    [WPAnalytics track:WPAnalyticsStatEditorTappedOrderedList];
}

- (void)setHR
{
    [self.editorView setHR];
}

- (void)setIndent
{
    [self.editorView setIndent];
}

- (void)setOutdent
{
    [self.editorView setOutdent];
}

- (void)heading1
{
	[self.editorView heading1];
}

- (void)heading2
{
    [self.editorView heading2];
}

- (void)heading3
{
    [self.editorView heading3];
}

- (void)heading4
{
	[self.editorView heading4];
}

- (void)heading5
{
	[self.editorView heading5];
}

- (void)heading6
{
	[self.editorView heading6];
}

- (void)textColor
{
    // Save the selection location
	[self.editorView saveSelection];

    // Call the picker
    HRColorPickerViewController *colorPicker = [HRColorPickerViewController cancelableFullColorPickerViewControllerWithColor:[UIColor whiteColor]];
    colorPicker.delegate = self;
    colorPicker.tag = 1;
    colorPicker.title = NSLocalizedString(@"Text Color", nil);
    [self.navigationController pushViewController:colorPicker animated:YES];
}

- (void)bgColor
{
    // Save the selection location
	[self.editorView saveSelection];
    
    // Call the picker
    HRColorPickerViewController *colorPicker = [HRColorPickerViewController cancelableFullColorPickerViewControllerWithColor:[UIColor whiteColor]];
    colorPicker.delegate = self;
    colorPicker.tag = 2;
    colorPicker.title = NSLocalizedString(@"BG Color", nil);
    [self.navigationController pushViewController:colorPicker animated:YES];
}

- (void)setSelectedColor:(UIColor*)color tag:(int)tag
{
    [self.editorView setSelectedColor:color tag:tag];
}

- (void)undo:(ZSSBarButtonItem *)barButtonItem
{
    [self.editorView undo];
}

- (void)redo:(ZSSBarButtonItem *)barButtonItem
{
    [self.editorView redo];
}

- (void)linkBarButtonTapped:(WPEditorToolbarButton*)button
{
	[self.editorView saveSelection];
	
	if ([self.editorView isSelectionALink]) {
		[self removeLink];
	} else {
		[self showInsertLinkDialogWithLink:self.editorView.selectedLinkURL
									 title:[self.editorView selectedText]];
		[WPAnalytics track:WPAnalyticsStatEditorTappedLink];
	}
}

- (void)showInsertLinkDialogWithLink:(NSString*)url
							   title:(NSString*)title
{
    
	BOOL isInsertingNewLink = (url == nil);
	
	if (!url) {
		NSURL* pasteboardUrl = [self urlFromPasteboard];
		
		url = [pasteboardUrl absoluteString];
	}
	
	NSString *insertButtonTitle = isInsertingNewLink ? NSLocalizedString(@"Insert", nil) : NSLocalizedString(@"Update", nil);
	NSString *removeButtonTitle = isInsertingNewLink ? nil : NSLocalizedString(@"Remove Link", nil);
	
	self.alertView = [[UIAlertView alloc] initWithTitle:insertButtonTitle
												message:nil
											   delegate:self
									  cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
									  otherButtonTitles:insertButtonTitle, removeButtonTitle, nil];
	
	// The reason why we're setting a login & password style, is that it's the only style that
	// supports having two edit fields.  We'll customize the password field to behave as we want.
	//
    self.alertView.alertViewStyle = UIAlertViewStyleLoginAndPasswordInput;
    self.alertView.tag = WPLinkAlertViewTag;
	
	UITextField *linkURL = [self.alertView textFieldAtIndex:0];
	
	linkURL.clearButtonMode = UITextFieldViewModeAlways;
	linkURL.placeholder = NSLocalizedString(@"URL", nil);
	
    if (url) {
        linkURL.text = url;
    }
	
	UITextField *linkNameTextField = [self.alertView textFieldAtIndex:1];
	
	linkNameTextField.clearButtonMode = UITextFieldViewModeAlways;
	linkNameTextField.placeholder = NSLocalizedString(@"Link Name", nil);
	linkNameTextField.secureTextEntry = NO;
	linkNameTextField.autocapitalizationType = UITextAutocapitalizationTypeSentences;
	linkNameTextField.autocorrectionType = UITextAutocorrectionTypeDefault;
	linkNameTextField.spellCheckingType = UITextSpellCheckingTypeDefault;
	
	if (title) {
		linkNameTextField.text = title;
	}
	
    __weak __typeof(self) weakSelf = self;

    self.alertView.willPresentBlock = ^(UIAlertView* alertView) {
        
        [weakSelf.editorView saveSelection];
        [weakSelf.editorView endEditing];
    };
	
	self.alertView.didDismissBlock = ^(UIAlertView *alertView, NSInteger buttonIndex) {
		[weakSelf.editorView restoreSelection];
		
		if (alertView.tag == WPLinkAlertViewTag) {
			if (buttonIndex == 1) {
				NSString *linkURL = [alertView textFieldAtIndex:0].text;
				NSString *linkTitle = [alertView textFieldAtIndex:1].text;
                
				if ([linkTitle length] == 0) {
					linkTitle = linkURL;
				}
                
				if (isInsertingNewLink) {
					[weakSelf insertLink:linkURL title:linkTitle];
				} else {
					[weakSelf updateLink:linkURL title:linkTitle];
				}
			} else if (buttonIndex == 2) {
				[weakSelf removeLink];
			}
		}
    };
	
    self.alertView.shouldEnableFirstOtherButtonBlock = ^BOOL(UIAlertView *alertView) {
		if (alertView.tag == WPLinkAlertViewTag) {
            UITextField *textField = [alertView textFieldAtIndex:0];
            if ([textField.text length] == 0) {
                return NO;
            }
        }
        return YES;
    };
    
    [self.alertView show];
}

- (void)insertLink:(NSString *)url
			 title:(NSString*)title
{
	[self.editorView insertLink:url title:title];
}

- (void)updateLink:(NSString *)url
			 title:(NSString*)title
{
	[self.editorView updateLink:url title:title];
}

- (void)dismissAlertView
{
    [self.alertView dismissWithClickedButtonIndex:self.alertView.cancelButtonIndex animated:YES];
}

- (void)addCustomToolbarItemWithButton:(UIButton *)button
{
    if(self.customBarButtonItems == nil)
    {
        self.customBarButtonItems = [NSMutableArray array];
    }
    
    button.titleLabel.font = [UIFont fontWithName:@"HelveticaNeue-UltraLight" size:28.5f];
    [button setTitleColor:self.toolbarItemTintColor forState:UIControlStateNormal];
    [button setTitleColor:self.toolbarItemSelectedTintColor forState:UIControlStateHighlighted];
    
    UIBarButtonItem *barButtonItem = [[UIBarButtonItem alloc] initWithCustomView:button];
    [self.customBarButtonItems addObject:barButtonItem];
    
    [self buildToolbar];
}

- (void)removeLink
{
    [self.editorView removeLink];
    [WPAnalytics track:WPAnalyticsStatEditorTappedUnlink];
}

- (void)quickLink
{
    [self.editorView quickLink];
}

- (void)insertImage:(NSString *)url alt:(NSString *)alt
{
	[self.editorView insertImage:url alt:alt];
}

- (void)updateImage:(NSString *)url alt:(NSString *)alt
{
    [self.editorView updateImage:url alt:alt];
}

- (void)selectToolbarItemsForStyles:(NSArray*)styles
{
	NSArray *items = self.leftToolbar.items;
	
    for (UIBarButtonItem *item in items) {
        // Since we're using UIBarItem as negative separators, we need to make sure we don't try to
        // use those here.
        //
        if ([item isKindOfClass:[ZSSBarButtonItem class]]) {
            ZSSBarButtonItem* zssItem = (ZSSBarButtonItem*)item;
            
            if ([styles containsObject:zssItem.htmlProperty]) {
                zssItem.selected = YES;
            } else {
                zssItem.selected = NO;
            }
        }
    }
}

#pragma mark - UIPasteboard interaction

/**
 *	@brief		Returns an URL from the general pasteboard.
 *
 *	@param		The URL or nil if no valid URL is found.
 */
- (NSURL*)urlFromPasteboard
{
	NSURL* url = nil;
	
	UIPasteboard* pasteboard = [UIPasteboard generalPasteboard];
	
	NSString* const kURLPasteboardType = (__bridge NSString*)kUTTypeURL;
	NSString* const kTextPasteboardType = (__bridge NSString*)kUTTypeText;
	
	if ([pasteboard containsPasteboardTypes:@[kURLPasteboardType]]) {
		url = [pasteboard valueForPasteboardType:kURLPasteboardType];
	} else if ([pasteboard containsPasteboardTypes:@[kTextPasteboardType]]) {
		NSString* urlString = [pasteboard valueForPasteboardType:kTextPasteboardType];
		
		NSURL* prevalidatedUrl = [NSURL URLWithString:urlString];
		
		if ([self isURLValid:prevalidatedUrl]) {
			url = prevalidatedUrl;
		}
	}
	
	return url;
}

/**
 *	@brief		Validates a URL.
 *	@details	The validations we perform here are pretty basic.  But the idea of having this
 *				method is to add any additional checks we want to perform, as we come up with them.
 *
 *	@parameter	url		The URL to validate.  You will usually call [NSURL URLWithString] to create
 *						this URL from a string, before passing it to this method.  Cannot be nil.
 */
- (BOOL)isURLValid:(NSURL*)url
{
	NSParameterAssert([url isKindOfClass:[NSURL class]]);
	
	return url && url.scheme && url.host;
}

#pragma mark - WPEditorViewDelegate

- (void)editorTextDidChange:(WPEditorView*)editorView
{
	if ([self.delegate respondsToSelector: @selector(editorTextDidChange:)]) {
		[self.delegate editorTextDidChange:self];
	}
}

- (void)editorTitleDidChange:(WPEditorView *)editorView
{
    if ([self.delegate respondsToSelector: @selector(editorTitleDidChange:)]) {
        [self.delegate editorTitleDidChange:self];
    }
}

- (void)editorViewDidFinishLoadingDOM:(WPEditorView*)editorView
{
	// DRM: the reason why we're doing is when the DOM finishes loading, instead of when the full
	// content finishe loading, is that the content may not finish loading at all when the device is
	// offline and the content has remote subcontent (such as pictures).
	//
    self.didFinishLoadingEditor = YES;
    
	if (self.editing) {
		[self startEditing];
	} else {
		[self.editorView disableEditing];
	}
    
    [self tellOurDelegateEditorDidFinishLoadingDOM];
}

- (void)editorView:(WPEditorView*)editorView
      fieldCreated:(WPEditorField*)field
{
    if (field == self.editorView.titleField) {
        field.inputAccessoryView = self.mainToolbarHolder;
        
        NSString* placeholderHTMLString = NSLocalizedString(@"Post title",
                                                            @"Placeholder for the post title.");
        
        [field setRightToLeftTextEnabled:[self isCurrentLanguageDirectionRTL]];
        [field setMultiline:NO];
        [field setPlaceholderText:placeholderHTMLString];
        [field setPlaceholderColor:[UIColor colorWithHexString:@"c6c6c6"]];
    } else if (field == self.editorView.contentField) {
        field.inputAccessoryView = self.mainToolbarHolder;
        
        NSString* placeholderHTMLString = NSLocalizedString(@"Share your story here...",
                                                            @"Placeholder for the post body.");
        
        [field setRightToLeftTextEnabled:[self isCurrentLanguageDirectionRTL]];
        [field setMultiline:YES];
        [field setPlaceholderText:placeholderHTMLString];
        [field setPlaceholderColor:[UIColor colorWithHexString:@"c6c6c6"]];
    }
    
    if ([self.delegate respondsToSelector:@selector(editorViewController:fieldCreated:)]) {
        [self.delegate editorViewController:self fieldCreated:field];
    }
}

- (void)editorView:(WPEditorView*)editorView
      fieldFocused:(WPEditorField*)field
{
    if (!field || field == self.editorView.titleField) {
        [self enableToolbarItems:NO shouldShowSourceButton:YES];
    } else if (field == self.editorView.contentField) {
        [self enableToolbarItems:YES shouldShowSourceButton:YES];
    }
}

- (BOOL)editorView:(WPEditorView*)editorView
		linkTapped:(NSURL *)url
			 title:(NSString*)title
{
	if (self.isEditing) {
        [self showInsertLinkDialogWithLink:url.absoluteString
                                     title:title];
	}
	
	return YES;
}

- (void)editorView:(WPEditorView*)editorView stylesForCurrentSelection:(NSArray*)styles
{
    self.editorItemsEnabled = styles;
	
	[self selectToolbarItemsForStyles:styles];
}


#ifdef DEBUG
-      (void)webView:(UIWebView *)webView
didFailLoadWithError:(NSError *)error
{
	DDLogError(@"Loading error: %@", error);
	NSAssert(NO,
			 @"This should never happen since the editor is a local HTML page of our own making.");
}
#endif

#pragma mark - Asset Picker

- (void)showInsertURLAlternatePicker
{
    // Blank method. User should implement this in their subclass
	NSAssert(NO, @"Blank method. User should implement this in their subclass");
}

- (void)showInsertImageAlternatePicker
{
    // Blank method. User should implement this in their subclass
	NSAssert(NO, @"Blank method. User should implement this in their subclass");
}

#pragma mark - Utilities

- (BOOL)isIPhoneSixPlus
{
    return IS_IPHONE && ([[UIScreen mainScreen] respondsToSelector:@selector(nativeScale)] && [[UIScreen mainScreen] nativeScale] > 2.5f);
}

- (UIColor *)barButtonItemDefaultColor
{
    if (self.toolbarItemTintColor) {
        return self.toolbarItemTintColor;
    }
    
    return [WPStyleGuide allTAllShadeGrey];
}

- (UIColor *)barButtonItemSelectedDefaultColor
{
    if (self.toolbarItemSelectedTintColor) {
        return self.toolbarItemSelectedTintColor;
    }
    return [WPStyleGuide wordPressBlue];
}

- (void)enableToolbarItems:(BOOL)enable
	shouldShowSourceButton:(BOOL)showSource
{
    NSArray *items = self.leftToolbar.items;
	
    for (ZSSBarButtonItem *item in items) {
        if (item.tag == kWPEditorViewControllerElementShowSourceBarButton) {
            item.enabled = showSource;
        } else {
            item.enabled = enable;
			
			if (!enable) {
				[item setSelected:NO];
			}
        }
    }
}

- (BOOL)isCurrentLanguageDirectionRTL
{
    return ([UIApplication sharedApplication].userInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft);
}

#pragma mark - Delegate calls

- (void)tellOurDelegateEditingDidBegin
{
	NSAssert(self.isEditing,
			 @"Can't call this delegate method if not editing.");
	
	if ([self.delegate respondsToSelector: @selector(editorDidBeginEditing:)]) {
		[self.delegate editorDidBeginEditing:self];
	}
}

- (void)tellOurDelegateEditingDidEnd
{
	NSAssert(!self.isEditing,
			 @"Can't call this delegate method if editing.");
	
	if ([self.delegate respondsToSelector: @selector(editorDidEndEditing:)]) {
		[self.delegate editorDidEndEditing:self];
	}
}

- (void)tellOurDelegateEditorDidFinishLoadingDOM
{
    if ([self.delegate respondsToSelector:@selector(editorDidFinishLoadingDOM:)]) {
        [self.delegate editorDidFinishLoadingDOM:self];
    }
}

@end
