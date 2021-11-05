//
//  SDScanViewController.m
//  SDScanDemo
//
//  Created by 王巍栋 on 2020/6/29.
//  Copyright © 2020 骚栋. All rights reserved.
//

#import "SDScanViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <Vision/Vision.h>
#import "SDScanMaskView.h"
#import "SDScanHeader.h"

@interface SDScanViewController ()<AVCaptureVideoDataOutputSampleBufferDelegate>

@property(nonatomic,strong)SDScanConfig *config;
@property(nonatomic,strong)AVCaptureDevice *device;
@property(nonatomic,strong)AVCaptureSession *session;
@property(nonatomic,strong)AVCaptureVideoPreviewLayer *previewLayer;
@property(nonatomic,strong)NSArray *request;

@property(nonatomic,strong)SDScanMaskView *maskView;

@end

@implementation SDScanViewController

- (instancetype)initWithConfig:(SDScanConfig *)scanConfig {
    
    if (self = [super init]) {
        self.config = scanConfig;
    }
    return self;
}

- (void)viewDidLoad {
    
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    [self startRunCameraScanAction];
    [self.view addSubview:self.maskView];
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    
    return UIStatusBarStyleLightContent;
}

#pragma mark - 懒加载

- (SDScanMaskView *)maskView {
    
    if (_maskView == nil) {
        _maskView = [[SDScanMaskView alloc] initWithFrame:self.view.bounds config:self.config];
        __weak typeof(self) weakSelf = self;
        _maskView.exitBlock = ^{
            [weakSelf dismissViewControllerAnimated:YES completion:nil];
        };
    }
    return _maskView;
}

- (NSArray *)request {
    
    if (_request == nil) {
        __weak typeof(self) weakSelf = self;

        VNDetectBarcodesRequest *request = [[VNDetectBarcodesRequest alloc] initWithCompletionHandler:^(VNRequest * _Nonnull request, NSError * _Nullable error) {
            if (error) {
                NSLog(@"error %@", [error localizedDescription]);
                return;
            }
            
            NSArray *results = request.results;
            for (id result in results) {
                if ([result isKindOfClass:[VNBarcodeObservation class]]) {
                    VNBarcodeObservation *observation = (VNBarcodeObservation *)result;

                    NSString *qrValue = nil;
                    if (observation.payloadStringValue) {
                        qrValue = observation.payloadStringValue;
                    } else {
                        CIQRCodeDescriptor *descriptor = (CIQRCodeDescriptor *)observation.barcodeDescriptor;
                        NSData *data = descriptor.errorCorrectedPayload;
                        const unsigned char *dataBuffer = (const unsigned char *)[data bytes];

                        if (!dataBuffer) {
                            continue;
                        }

                        NSUInteger          dataLength  = [data length];
                        NSMutableString     *hexString  = [NSMutableString stringWithCapacity:(dataLength * 2)];

                        for (int i = 0; i < dataLength; ++i) {
                            [hexString appendFormat:@"%02x", (unsigned int)dataBuffer[i]];
                        }

                        qrValue = [NSString stringWithString:hexString];
                    }
                    
                    
                    [weakSelf.session stopRunning];
                    
                    if (weakSelf.config.resultBlock != nil) {
                        weakSelf.config.resultBlock(qrValue);
                    }
                    [weakSelf dismissViewControllerAnimated:YES completion:nil];

                    break;
                }
            }
        }];
        request.symbologies = @[VNBarcodeSymbologyQR];
        _request = @[request];
    }
    return _request;
}

#pragma mark - 扫描相关

// 开始扫描
- (void)startRunCameraScanAction {
    self.device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    AVCaptureDeviceInput * videoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:self.device error:nil];
    AVCaptureVideoDataOutput * videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
    [videoDataOutput setSampleBufferDelegate:self queue:dispatch_get_main_queue()];
    
    self.session = [[AVCaptureSession alloc] init];
    self.session.sessionPreset = AVCaptureSessionPresetHigh;
    
    [self.session addInput:videoDeviceInput];
    [self.session addOutput:videoDataOutput];
    
    self.previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.session];
    self.previewLayer.frame = self.view.bounds;
    self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    self.previewLayer.backgroundColor = [UIColor yellowColor].CGColor;
    [self.view.layer addSublayer:self.previewLayer];
    
    [self.session startRunning];
}

// 扫描结果
- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    if (!CMSampleBufferGetImageBuffer(sampleBuffer)) {
        return;
    }
    
    id dict = nil;
        
    if (@available(iOS 11.0, *)) {
        //
    } else {
        return;
    }

    CFTypeRef ref = CMGetAttachment(sampleBuffer, kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, nil);
    if (ref) {
        dict = VNImageOptionCameraIntrinsics;
    }
    
    VNImageRequestHandler* requestHadler = [[VNImageRequestHandler alloc] initWithCVPixelBuffer:CMSampleBufferGetImageBuffer(sampleBuffer) options:dict];
        
    @try {
        [requestHadler performRequests:self.request error:nil];
    }
    @catch (NSException *exception) {
        NSLog(@"AAA - %@", exception.reason);
    }
}

@end

