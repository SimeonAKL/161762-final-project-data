
/*Step 1 — 导入数据*/
proc import datafile="/home/u64461556/Final_Dataset/18-garment_employee_productivity.csv"
    out=garment
    dbms=csv
    replace;
    guessingrows=max;
run;

/*
这个 dataset 里面有什么变量？每个变量是什么类型？”

结果显示：

数据集叫 WORK.GARMENT
一共有 1197 rows
一共有 15 variables
*/

/*Step 2 — 检查变量类型*/
proc contents data=garment;
run;
/*
我们用 PROC CONTENTS 来了解数据结构，包括有多少行、多少变量，以及变量类型。
*/


/*Step 3 — 检查 Missing Values（非常重要）*/
proc means data=garment n nmiss;
run;
/*
每个 numeric variable 有多少有效值，有多少 missing values？
结果最重要的是：

wip: N = 691, N Miss = 506

也就是说，wip 有 506 个缺失值。其他主要数值变量基本没有 missing values。 
*/


/*Step 4 — 处理 Missing Values（高分关键）*/

proc stdize data=garment
    reponly
    method=median
    out=garment_clean;
    var wip;
run;
/*用中位数替换缺失值。
为什么不用 mean？
因为：WIP 非常 skewed。你们后面已经发现：skewness = 12.89 这是：极度偏态。
如果用 mean：会被 extreme values 拉歪。median 更稳。*/


/*Step 5 — 修正变量问题（重要）*/
data garment_clean;
    set garment_clean;

    if department="sweing" then department="sewing";
run;

/*修正拼写错误*/



/*Step 6 — 日期变量处理*/
data garment_clean;
    set garment_clean;

    date2 = input(date, mmddyy10.);
    format date2 date9.;
run;
/*把 date 转成真正 SAS date format。*/


/*Step 7 — 检查异常值（Outliers）*/

proc univariate data=garment_clean;
    var actual_productivity smv wip over_time;
    histogram;
run;
/*检查变量分布。
主要看：
指标	意义
Mean	平均值
Median	中位数
Skewness	偏态
Range	范围
Histogram	分布图
Extreme values	极端值

actual_productivity
整体偏高。
smv
variation 很大
wip
极度右偏。
over_time
差异很大。

为什么进行这一步：PCA/clustering 很怕 extreme values。
所以：
通过这个步骤发现: 必须 standardise。
*/

/*Step 8 — Standardization（超级重要)*/

proc standard data=garment_clean
    mean=0
    std=1
    out=garment_scaled;

    var targeted_productivity
        smv
        wip
        over_time
        incentive
        idle_time
        idle_men
        no_of_style_change
        no_of_workers
        actual_productivity;
run;
/*把所有变量变成同一尺度。*/


/*Step 9 — 删除不适合 PCA 的变量*/
/*保留：
targeted_productivity
smv
wip
over_time
incentive
idle_time
idle_men
no_of_style_change
no_of_workers
actual_productivity*/

/*为什么保留？

因为这些：

都是 numeric
都代表 operational/productivity patterns
有 variation
有 multivariate structure

非常适合 PCA。*/

/*删除:
Variable	为什么不适合
department	categorical
quarter	categorical
day	categorical
date2	date variable
team	更像 group ID
PCA 会误以为：
team 10 > team 2
*/


