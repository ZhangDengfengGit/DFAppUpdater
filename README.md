# DFAppUpdater
检查AppStore中是否有较新版本的应用程序，并提醒用户进行可选和强制更新。
# 特征
- 一行代码
- 毫秒响应
- 线程安全
- 在alert中显示版本号
- 从alert中打开AppStore中的应用
- 选择不立即更新或强制用户更新
- 支持本地化
- 委托方法
# 用法
将宏定义KAPPID @""改为自己的App的id
在AppDelegate中开启即可
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
   [[ATAppUpdater sharedUpdater] showUpdateWithConfirmation];
   return YES;
}
