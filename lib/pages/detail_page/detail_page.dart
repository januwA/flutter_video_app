import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_video_app/models/detail_data_dto/detail_data_dto.dart';
import 'package:flutter_video_app/shared/globals.dart';
import 'package:flutter_video_app/shared/widgets/alert_http_get_error.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart';
import 'package:http/http.dart' as http;

class DetailPage extends StatefulWidget {
  DetailPage({
    Key key,
    @required this.id,
  }) : super(key: key);
  final String id;
  @override
  _DetailPageState createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  /// 页面数据
  DetailData detailData;
  Client client;
  VideoPlayerController videoCtrl;

  /// 当前播放位置
  int currentPlayIndex = 0;

  /// 当前播放的视频
  PlayUrlTab get currentPlayVideo => detailData.playUrlTab[currentPlayIndex];

  /// 页面状态

  bool isPageLoading = false;
  bool isVideoLoading = false;

  /// 当前时长
  Duration position;

  /// 总时长
  Duration duration;

  /// 是否显示控制器
  /// 播放 false
  /// 暂停 true
  bool isShowVideoControllers = true;

  /// 是否为全屏播放
  bool isFullScreen = false;

  /// 25:00 总时长
  String get durationText {
    if (duration == null) return '';
    var r = duration.toString().split('.').first.split(':')..removeAt(0);
    return r.join(':');
  }

  /// 00:01 当前时间
  String get positionText {
    if (videoCtrl.value == null) return '';
    var r = videoCtrl.value.position.toString().split('.').first.split(':')
      ..removeAt(0);
    return r.join(':');
  }

  double get sliderValue {
    if (position?.inSeconds != null && duration?.inSeconds != null) {
      return videoCtrl.value.position.inSeconds / duration.inSeconds;
    } else {
      return 0.0;
    }
  }

  @override
  void initState() {
    super.initState();
    this.getDetailData();
  }

  @override
  void dispose() {
    super.dispose();

    client?.close();
    videoCtrl?.removeListener(videoListenner);
    videoCtrl?.dispose();
  }

  videoListenner() {
    setState(() {});
  }

  /// 获取detail数据
  Future<void> getDetailData() async {
    setState(() => isPageLoading = true);
    try {
      client = http.Client();
      var url = Uri.http(baseUrl, detailUrl, {"id": widget.id});
      var r = await client.get(url);

      if (r.statusCode == 200) {
        setState(() {
          detailData = DetailDataDto.fromJson(r.body).detailData;
          isPageLoading = false;
        });
        // 设置完数据开始初始化播放器
        initVideoPlaer();
      } else {
        // 服务器没有正确的返回数据
        alertHttpGetError(
            context: context,
            text: r.body,
            onOk: () {
              getDetailData();
            });
      }
    } on ClientException catch (e) {
      print("http异常: $e");
    } catch (e) {
      print('Other Error: $e');
    }
  }

  /// 获取指定集的src
  getVideoSrc() async {
    var e = detailData.playUrlTab[currentPlayIndex];
    setState(() => isVideoLoading = true);
    var url = Uri.http(baseUrl, videoSrcUrl, {"id": e.id});
    var r = await http.get(url);
    if (r.statusCode == 200) {
      var src = jsonDecode(r.body)['src'];
      setState(() => isVideoLoading = false);
      initVideoPlaer(src);
    } else {
      alertHttpGetError(context: context, text: r.body);
    }
  }

  /// 初始化viedo控制器
  Future<void> initVideoPlaer([String src]) async {
    setState(() => isVideoLoading = true);
    videoCtrl =
        VideoPlayerController.network(src != null ? src : currentPlayVideo.src);

    await videoCtrl.initialize();

    videoCtrl.setVolume(1.0);
    setState(() {
      position = videoCtrl.value.position;
      duration = videoCtrl.value.duration;
      isVideoLoading = false;
    });

    // 用户点击了切换，加载完后自动播放
    if (src != null) {
      videoCtrl.play();
      setState(() => isShowVideoControllers = false);
    }
    videoCtrl.addListener(videoListenner);
  }

  @override
  Widget build(BuildContext context) {
    if (isPageLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('数据加载中...'),
        ),
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (isFullScreen) {
      MediaQueryData deviceData = MediaQuery.of(context);
      return SafeArea(
        child: Scaffold(
          body: SizedBox(
            width: deviceData.size.width,
            height: deviceData.size.height,
            child: videoBox(),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(detailData.videoName),
      ),
      body: ListView(
        children: <Widget>[
          videoBox(),
          DetailInfo(detailData: detailData),
          ExpansionTile(
            title: Text(
              detailData.plot,
              overflow: TextOverflow.ellipsis,
            ),
            children: <Widget>[
              Padding(
                padding: EdgeInsets.all(8),
                child: Text(detailData.plot),
              ),
            ],
          ),
          Center(
            child: Wrap(
              alignment: WrapAlignment.spaceAround,
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                for (PlayUrlTab t in detailData.playUrlTab) playTab(t)
              ],
            ),
          ),
        ],
      ),
    );
  }

  GestureDetector videoBox() {
    return GestureDetector(
      onTap: () async {
        setState(() {
          isShowVideoControllers = !isShowVideoControllers;
        });
      },
      child: Stack(
        alignment: AlignmentDirectional.center,
        children: <Widget>[
          isVideoLoading
              ? AspectRatio(
                  aspectRatio: 16.0 / 9.0,
                  child: Container(
                    color: Colors.black,
                    child: Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    ),
                  ),
                )
              : AspectRatio(
                  aspectRatio: videoCtrl.value.aspectRatio,
                  child: VideoPlayer(videoCtrl),
                ),
          isVideoLoading
              ? CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                )
              : AnimatedCrossFade(
                  duration: Duration(milliseconds: 300),
                  firstChild: Container(),
                  secondChild: Container(
                    decoration: new BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      color: Colors.black,
                      icon: Icon(videoCtrl.value.isPlaying
                          ? Icons.pause
                          : Icons.play_arrow),
                      onPressed: () {
                        if (videoCtrl.value.isPlaying) {
                          videoCtrl.pause();
                          setState(() {
                            isShowVideoControllers = true;
                          });
                        } else {
                          videoCtrl.play();
                          setState(() {
                            isShowVideoControllers = false;
                          });
                        }
                      },
                    ),
                  ),
                  crossFadeState: isShowVideoControllers
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: AnimatedCrossFade(
              duration: Duration(milliseconds: 300),
              firstChild: Container(),
              secondChild: Container(
                decoration: BoxDecoration(color: Colors.black45),
                child: Column(
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: <Widget>[
                          Text(
                            "$positionText / $durationText",
                            style: TextStyle(color: Colors.white),
                          ),
                          Spacer(),
                          if (!isVideoLoading)
                            SmallIconButton(
                              icon: Icon(
                                videoCtrl.value.volume <= 0
                                    ? Icons.volume_off
                                    : Icons.volume_up,
                                color: Colors.white,
                              ),
                              onTap: () {
                                if (videoCtrl.value.volume > 0) {
                                  videoCtrl.setVolume(0.0);
                                } else {
                                  videoCtrl.setVolume(1.0);
                                }
                              },
                            ),
                          SmallIconButton(
                            icon: Icon(
                              !isFullScreen
                                  ? Icons.fullscreen
                                  : Icons.fullscreen_exit,
                              color: Colors.white,
                            ),
                            onTap: onFullScreen,
                          ),
                        ],
                      ),
                    ),
                    Slider(
                      inactiveColor: Colors.grey,
                      value: sliderValue,
                      onChanged: (v) {
                        var to =
                            Duration(seconds: (v * duration.inSeconds).toInt());
                        videoCtrl.seekTo(to);
                      },
                    ),
                  ],
                ),
              ),
              crossFadeState: isShowVideoControllers
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
            ),
          ),
        ],
      ),
    );
  }

  onFullScreen() {
    if (isFullScreen) {
      setPortrait();
    } else {
      setLandscape();
    }
  }

  /// 设置为横屏模式
  setLandscape() {
    setState(() {
      isFullScreen = true;
    });
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);
  }

  /// 设置为正常模式
  setPortrait() {
    setState(() {
      isFullScreen = false;
    });
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  /// 每集 tab
  playTab(PlayUrlTab t) {
    var index = detailData.playUrlTab.indexOf(t);
    return RaisedButton(
      color: index == currentPlayIndex ? Colors.blue[400] : Colors.grey[300],
      child: Text(t.text),
      onPressed: () async {
        if (t.isBox) {
          // 网盘资源
          if (await canLaunch(t.src)) {
            await launch(t.src);
          } else {
            throw 'Could not launch ${t.src}';
          }
        } else {
          // 视频资源,准备切换播放点击的视频
          setState(() {
            currentPlayIndex = index;
            isShowVideoControllers = true;
          });
          getVideoSrc();
        }
      },
    );
  }
}

class DetailInfo extends StatelessWidget {
  const DetailInfo({
    Key key,
    @required this.detailData,
  }) : super(key: key);

  final detailData;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text.rich(
            TextSpan(
              text: '${detailData.videoName}',
              style: Theme.of(context).textTheme.title,
              children: <TextSpan>[
                TextSpan(
                    text: '${detailData.curentText}',
                    style: Theme.of(context).textTheme.subtitle),
              ],
            ),
          ),
          Wrap(
            children: <Widget>[
              Text('主演:'),
              for (String name in detailData.starring)
                Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text(name)),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              Text('导演:'),
              Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text(detailData.director)),
            ],
          ),
          Wrap(
            children: <Widget>[
              Text('类型:'),
              for (String name in detailData.types)
                Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text(name)),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              Text('地区:'),
              Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text(detailData.area)),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              Text('年份:'),
              Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text(detailData.years)),
            ],
          ),
        ],
      ),
    );
  }
}

/// video 控制器上的按钮
class SmallIconButton extends StatelessWidget {
  SmallIconButton({
    Key key,
    this.icon,
    this.onTap,
    this.padding = const EdgeInsets.all(4.0),
  }) : super(key: key);
  final Widget icon;
  final EdgeInsetsGeometry padding;
  final Function onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: padding,
        child: icon,
      ),
    );
  }
}
