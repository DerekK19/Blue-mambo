//
//  DGKBMainControllerViewController.m
//  Blue-mambo
//
//  Created by Derek Knight on 23/04/15.
//  Copyright (c) 2015 ASB. All rights reserved.
//

#import "DGKBMainController.h"

@interface DGKBMainController ()

@end

@implementation DGKBMainController

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    NSString *title = [[NSUserDefaults standardUserDefaults] objectForKey:@"DGKBMainController.SelectedIndex"];
    NSInteger index = 0;
    for (UITabBarItem *item in self.viewControllers) {
        if ([title isEqualToString:item.title]) {
            [self setSelectedIndex:index];
        }
        index++;
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)tabBar:(UITabBar *)tabBar
 didSelectItem:(UITabBarItem *)item
{
    DEBUGLog(@"%@", item.title);
    [[NSUserDefaults standardUserDefaults] setObject:item.title forKey:@"DGKBMainController.SelectedIndex"];
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
