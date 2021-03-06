//
//  CCPlayBackController.m
//  CCLiveCloud
//
//  Created by MacBook Pro on 2018/11/20.
//  Copyright © 2018 MacBook Pro. All rights reserved.
//

#import "CCPlayBackController.h"
#import "CCPlayBackView.h"//视频视图
#import "CCSDK/RequestDataPlayBack.h"//sdk
#import "CCSDK/SaveLogUtil.h"//日志
#import "CCPlayBackInteractionView.h"//回放互动视图

@interface CCPlayBackController ()<RequestDataPlayBackDelegate,UIScrollViewDelegate, CCPlayBackViewDelegate>

@property (nonatomic,strong)CCPlayBackInteractionView   * interactionView;//互动视图
@property (nonatomic,strong)CCPlayBackView              * playerView;//视频视图
@property (nonatomic,strong)RequestDataPlayBack         * requestDataPlayBack;//sdk

@property (nonatomic,copy)  NSString                    * groupId;//聊天分组
@end

@implementation CCPlayBackController

- (void)viewDidLoad {
    [super viewDidLoad];
    //初始化背景颜色，设置状态栏样式
    self.view.backgroundColor = [UIColor blackColor];
    [UIApplication sharedApplication].statusBarStyle = UIStatusBarStyleLightContent;
    
    [self setupUI];//设置UI布局
    [self addObserver];//添加通知
    [self integrationSDK];//集成SDK
}

//集成SDK
- (void)integrationSDK {
    PlayParameter *parameter = [[PlayParameter alloc] init];
    parameter.userId = GetFromUserDefaults(PLAYBACK_USERID);//userId
    parameter.roomId = GetFromUserDefaults(PLAYBACK_ROOMID);//roomId
    parameter.liveId = GetFromUserDefaults(PLAYBACK_LIVEID);//liveId
    parameter.recordId = GetFromUserDefaults(PLAYBACK_RECORDID);//回放Id
    parameter.viewerName = GetFromUserDefaults(PLAYBACK_USERNAME);//用户名
    parameter.token = GetFromUserDefaults(PLAYBACK_PASSWORD);//密码
    parameter.docParent = self.playerView.smallVideoView;//文档小窗
    parameter.docFrame = CGRectMake(0, 0, self.playerView.smallVideoView.frame.size.width, self.playerView.smallVideoView.frame.size.height);//文档小窗大小
    parameter.playerParent = self.playerView;//视频视图
    parameter.playerFrame = CGRectMake(0, 0,self.playerView.frame.size.width, self.playerView.frame.size.height);//视频位置,ps:起始位置为视频视图坐标
    parameter.security = YES;//是否开启https,建议开启
    parameter.PPTScalingMode = 4;//ppt展示模式,建议值为4
    parameter.pauseInBackGround = YES;//后台是否暂停
    parameter.defaultColor = [UIColor whiteColor];//ppt默认底色，不写默认为白色
    parameter.scalingMode = 1;//屏幕适配方式
    parameter.pptInteractionEnabled = NO;//是否开启ppt滚动
//        parameter.groupid = self.groupId;//用户的groupId
    _requestDataPlayBack = [[RequestDataPlayBack alloc] initWithParameter:parameter];
    _requestDataPlayBack.delegate = self;
    
    /* 设置playerView */
    [self.playerView showLoadingView];//显示视频加载中提示
}
#pragma mark- 必须实现的代理方法

/**
 *    @brief    请求成功
 */
-(void)requestSucceed {
    //    NSLog(@"请求成功！");
}

/**
 *    @brief    登录请求失败
 */
-(void)requestFailed:(NSError *)error reason:(NSString *)reason {
    NSString *message = nil;
    if (reason == nil) {
        message = [error localizedDescription];
    } else {
        message = reason;
    }
}

#pragma mark-----------------------功能代理方法 用哪个实现哪个-------------------------------
#pragma mark - 服务端给自己设置的信息
/**
 *    @brief    服务器端给自己设置的信息(The new method)
 *    groupId 分组id
 *    name 用户名
 */
-(void)setMyViewerInfo:(NSDictionary *) infoDic{
    //如果没有groupId这个字段,设置groupId为空(为空时默认显示所有聊天)
    //    if([[infoDic allKeys] containsObject:@"groupId"]){
    //        _groupId = infoDic[@"groupId"];
    //    }else{
    //        _groupId = @"";
    //    }
    _groupId = @"";
    _interactionView.groupId = _groupId;
}
#pragma mark- 房间信息
/**
 *    @brief  获取房间信息，主要是要获取直播间模版来类型，根据直播间模版类型来确定界面布局
 *    房间简介：dic[@"desc"];
 *    房间名称：dic[@"name"];
 *    房间模版类型：[dic[@"templateType"] integerValue];
 *    模版类型为1: 聊天互动： 无 直播文档： 无 直播问答： 无
 *    模版类型为2: 聊天互动： 有 直播文档： 无 直播问答： 有
 *    模版类型为3: 聊天互动： 有 直播文档： 无 直播问答： 无
 *    模版类型为4: 聊天互动： 有 直播文档： 有 直播问答： 无
 *    模版类型为5: 聊天互动： 有 直播文档： 有 直播问答： 有
 *    模版类型为6: 聊天互动： 无 直播文档： 无 直播问答： 有
 */
-(void)roomInfo:(NSDictionary *)dic {
    //设置房间标题
    self.playerView.titleLabel.text = dic[@"name"];
    //配置互动视图的信息
    [self.interactionView roomInfo:dic];
}
#pragma mark- 回放的开始时间和结束时间
/**
 *  @brief 回放的开始时间和结束时间
 */
-(void)liveInfo:(NSDictionary *)dic {
//    NSLog(@"%@",dic);
     SaveToUserDefaults(LIVE_STARTTIME, dic[@"startTime"]);
}
#pragma mark- 聊天
/**
 *    @brief    解析本房间的历史聊天数据
 */
-(void)onParserChat:(NSArray *)chatArr {
    if ([chatArr count] == 0) {
        return;
    }
    //解析历史聊天
    [self.interactionView onParserChat:chatArr];
}
#pragma mark- 问答
/**
 *    @brief  收到提问&回答
 */
- (void)onParserQuestionArr:(NSArray *)questionArr onParserAnswerArr:(NSArray *)answerArr
{
    //    NSLog(@"questionArr = %@,answerArr = %@",questionArr,answerArr);
    [self.interactionView onParserQuestionArr:questionArr onParserAnswerArr:answerArr];
}
//监听播放状态
-(void)movieLoadStateDidChange:(NSNotification*)notification
{
    switch (_requestDataPlayBack.ijkPlayer.loadState)
    {
        case IJKMPMovieLoadStateStalled:
            break;
        case IJKMPMovieLoadStatePlayable:
            break;
        case IJKMPMovieLoadStatePlaythroughOK:
            break;
        default:
            break;
    }
}
//回放速率改变
- (void)moviePlayBackStateDidChange:(NSNotification*)notification
{
    switch (_requestDataPlayBack.ijkPlayer.playbackState)
    {
        case IJKMPMoviePlaybackStateStopped: {
            break;
        }
        case IJKMPMoviePlaybackStatePlaying:
        case IJKMPMoviePlaybackStatePaused: {
            if(self.playerView.pauseButton.selected == YES && [_requestDataPlayBack isPlaying]) {
                [_requestDataPlayBack pausePlayer];
            }
            if(self.playerView.loadingView && ![self.playerView.timer isValid]) {
                [self.playerView startTimer];
                [self.playerView removeLoadingView];//移除加载视图
                [[SaveLogUtil sharedInstance] saveLog:@"" action:SAVELOG_ALERT];
                [_requestDataPlayBack continueFromTheTime:0];
            }
            break;
        }
        case IJKMPMoviePlaybackStateInterrupted: {
            break;
        }
        case IJKMPMoviePlaybackStateSeekingForward:
        case IJKMPMoviePlaybackStateSeekingBackward: {
            break;
        }
        default: {
            break;
        }
    }
}
//移除通知
- (void)dealloc {
    [self removeObserver];
}
#pragma mark - 设置UI

/**
 创建UI
 */
- (void)setupUI {
    //添加视频播放视图
    [self.view addSubview:self.playerView];
    [self.playerView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.equalTo(self.view);
        make.height.mas_equalTo(CCGetRealFromPt(462));
        make.top.equalTo(self.view).offset(SCREEN_STATUS);
    }];
    [self.playerView layoutIfNeeded];
    
    //添加互动视图
    self.interactionView = [[CCPlayBackInteractionView alloc] initWithFrame:CGRectMake(0, CCGetRealFromPt(462)+SCREEN_STATUS, SCREEN_WIDTH,IS_IPHONE_X ? CCGetRealFromPt(835) + 90:CCGetRealFromPt(835))];
    self.interactionView.smallVideoView = self.playerView.smallVideoView;
    self.interactionView.playerView = self.playerView;
    [self.view addSubview:self.interactionView];
}
#pragma mark - playViewDelegate

/**
 开始播放时
 */
-(void)timerfunc{
    if([_requestDataPlayBack isPlaying]) {
        [self.playerView removeLoadingView];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSTimeInterval position = (int)round(self.requestDataPlayBack.currentPlaybackTime);
        NSTimeInterval duration = (int)round(self.requestDataPlayBack.playerDuration);
        //存在播放器最后一点不播放的情况，所以把进度条的数据对到和最后一秒想同就可以了
        if(duration - position == 1 && (self.playerView.sliderValue == position || self.playerView.sliderValue == duration)) {
            position = duration;
        }
        //            NSLog(@"---%f",_requestDataPlayBack.currentPlaybackTime);
        
        self.playerView.slider.maximumValue = (int)duration;
        self.playerView.rightTimeLabel.text = [NSString stringWithFormat:@"%02d:%02d", (int)(duration / 60), (int)(duration) % 60];
        
        if(position == 0 && self.playerView.sliderValue != 0) {
            self.requestDataPlayBack.currentPlaybackTime = self.playerView.sliderValue;
            position = self.playerView.sliderValue;
            self.playerView.slider.value = self.playerView.sliderValue;
        } else if(fabs(position - self.playerView.slider.value) > 10) {
            self.requestDataPlayBack.currentPlaybackTime = self.playerView.slider.value;
            position = self.playerView.slider.value;
            self.playerView.sliderValue = self.playerView.slider.value;
        } else {
            self.playerView.slider.value = position;
            self.playerView.sliderValue = self.playerView.slider.value;
        }
        
        if(self.requestDataPlayBack.ijkPlayer.playbackRate != self.playerView.playBackRate) {
            self.requestDataPlayBack.ijkPlayer.playbackRate = self.playerView.playBackRate;
            [self.playerView startTimer];
        }
        if(self.playerView.pauseButton.selected == NO && self.requestDataPlayBack.ijkPlayer.playbackState == IJKMPMoviePlaybackStatePaused) {
            [self.requestDataPlayBack startPlayer];
        }
        [self.requestDataPlayBack continueFromTheTime:self.playerView.sliderValue];
        [self parseChatOnTime:(int)self.playerView.sliderValue];
        self.playerView.leftTimeLabel.text = [NSString stringWithFormat:@"%02d:%02d", (int)(self.playerView.sliderValue / 60), (int)(self.playerView.sliderValue) % 60];
    });
}
/**
 全屏按钮点击代理
 
 @param tag 1视频为主，2文档为主
 */
-(void)quanpingBtnClicked:(NSInteger)tag{
    if (tag == 1) {
        [_requestDataPlayBack changePlayerFrame:self.view.frame];
    } else {
        [_requestDataPlayBack changeDocFrame:self.view.frame];
    }
    //隐藏互动视图
    [self hiddenInteractionView:YES];
}
/**
 返回按钮点击代理
 
 @param tag 1.视频为主，2.文档为主
 */
-(void)backBtnClicked:(NSInteger)tag{
    if (tag == 1) {
        [_requestDataPlayBack changePlayerFrame:CGRectMake(0, 0, SCREEN_WIDTH, CCGetRealFromPt(462))];
    } else {
        [_requestDataPlayBack changeDocFrame:CGRectMake(0, 0, SCREEN_WIDTH, CCGetRealFromPt(462))];
    }
    //显示互动视图
    [self hiddenInteractionView:NO];
}
/**
 切换视频/文档按钮点击回调
 
 @param tag changeBtn的tag值
 */
-(void)changeBtnClicked:(NSInteger)tag{
    if (tag == 2) {
        [_requestDataPlayBack changeDocParent:self.playerView];
        [_requestDataPlayBack changePlayerParent:self.playerView.smallVideoView];
        [_requestDataPlayBack changeDocFrame:CGRectMake(0, 0,self.playerView.frame.size.width, self.playerView.frame.size.height)];
        [_requestDataPlayBack changePlayerFrame:CGRectMake(0, 0, self.playerView.smallVideoView.frame.size.width, self.playerView.smallVideoView.frame.size.height)];
    }else{
        [_requestDataPlayBack changeDocParent:self.playerView.smallVideoView];
        [_requestDataPlayBack changePlayerParent:self.playerView];
        [_requestDataPlayBack changePlayerFrame:CGRectMake(0, 0,self.playerView.frame.size.width, self.playerView.frame.size.height)];
        [_requestDataPlayBack changeDocFrame:CGRectMake(0, 0, self.playerView.smallVideoView.frame.size.width, self.playerView.smallVideoView.frame.size.height)];
    }
}
/**
 隐藏互动视图

 @param hidden 是否隐藏
 */
-(void)hiddenInteractionView:(BOOL)hidden{
    self.interactionView.hidden = hidden;
}
/**
 通过传入时间获取聊天信息

 @param time 传入的时间
 */
-(void)parseChatOnTime:(int)time{
    [self.interactionView parseChatOnTime:time];
}
#pragma mark - 添加通知
//通知监听
-(void)addObserver {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillEnterBackgroundNotification) name:UIApplicationDidEnterBackgroundNotification object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillEnterForegroundNotification) name:UIApplicationWillEnterForegroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(moviePlayBackStateDidChange:)
                                                 name:IJKMPMoviePlayerPlaybackStateDidChangeNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(movieLoadStateDidChange:)
                                                 name:IJKMPMoviePlayerLoadStateDidChangeNotification
                                               object:nil];
}

//移除通知
-(void) removeObserver {
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationDidEnterBackgroundNotification
                                                  object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationWillEnterForegroundNotification
                                                  object:nil];
    [[NSNotificationCenter defaultCenter]removeObserver:self name:IJKMPMoviePlayerPlaybackStateDidChangeNotification object:nil];
    
    [[NSNotificationCenter defaultCenter]removeObserver:self name:IJKMPMoviePlayerLoadStateDidChangeNotification object:nil];
}

/**
 APP将要进入前台
 */
- (void)appWillEnterForegroundNotification {
    [self.playerView startTimer];
}

/**
 APP将要进入后台
 */
- (void)appWillEnterBackgroundNotification {
    UIApplication *app = [UIApplication sharedApplication];
    UIBackgroundTaskIdentifier taskID = 0;
    taskID = [app beginBackgroundTaskWithExpirationHandler:^{
        [app endBackgroundTask:taskID];
    }];
    if (taskID == UIBackgroundTaskInvalid) {
        return;
    }
    [self.playerView stopTimer];
}
#pragma mark - 懒加载
-(CCPlayBackView *)playerView{
    if (!_playerView) {
         _playerView = [[CCPlayBackView alloc] initWithFrame:CGRectZero];
        _playerView.delegate = self;
        
        //退出直播间回调
        WS(weakSelf)
        _playerView.exitCallBack = ^{
            [weakSelf.requestDataPlayBack requestCancel];
            weakSelf.requestDataPlayBack = nil;
            [weakSelf dismissViewControllerAnimated:YES completion:nil];
        };
        //滑块滑动完成回调
        _playerView.sliderCallBack = ^(int duration) {
            weakSelf.requestDataPlayBack.currentPlaybackTime = duration;
            if (weakSelf.requestDataPlayBack.ijkPlayer.playbackState != IJKMPMoviePlaybackStatePlaying) {
                [weakSelf.requestDataPlayBack startPlayer];
            }
        };
        //滑块移动回调
        _playerView.sliderMoving = ^{
            if (weakSelf.requestDataPlayBack.ijkPlayer.playbackState != IJKMPMoviePlaybackStatePaused) {
                [weakSelf.requestDataPlayBack pausePlayer];
            }
        };
        //更改播放器速率回调
        _playerView.changeRate = ^(float rate) {
            weakSelf.requestDataPlayBack.ijkPlayer.playbackRate = rate;
        };
        //暂停/开始播放回调
        _playerView.pausePlayer = ^(BOOL pause) {
            if (pause) {
                [weakSelf.requestDataPlayBack pausePlayer];
            }else{
                [weakSelf.requestDataPlayBack startPlayer];
            }
        };
    }
    return _playerView;
}
#pragma mark - 横竖屏旋转设置
//旋转方向
- (BOOL)shouldAutorotate{
    if (self.playerView.isScreenLandScape == YES) {
        return YES;
    }
    return NO;
}
- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation
{
    return UIInterfaceOrientationPortrait;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskAllButUpsideDown;
}

- (BOOL)prefersHomeIndicatorAutoHidden {

    return  YES;
}
@end
