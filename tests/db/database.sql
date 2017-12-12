create table apdt (
po_chg_rece_no char(30),
po_chg_rece_date char(30),
policy_no char(30),
po_chg_sts_code char(30));


create table apit (
po_chg_code char(30),
po_chg_rece_no char(30));


create table bank (
bank_code char(30),
bank_use_ind char(30),
bank_name char(30));


create table bpqi (
receive_no char(30));


create table chad (
chah_seq char(30),
invs_ad_sub_ind char(30),
invs_code char(30));


create table chah (
chah_seq char(30),
active_ind char(30),
policy_no char(30),
receive_no char(30),
bgn_date char(30));


create table chap (
chah_seq char(30),
policy_no char(30),
receive_no char(30));


create table chlh (
chah_seq char(30));


create table clnt (
client_id char(30),
names char(30));


create table pldf (
plan_code char(30),
rate_scale char(30));


create table pocl (
client_id char(30),
client_ident char(30),
policy_no char(30));


create table pofb (
client_id char(30),
policy_no char(30));


create table polf (
policy_no char(30),
policy_no char(30));


create table psra (
client_id char(30),
psra_sts_code char(30));


create table psrd (
receive_no char(30),
wt_item char(30),
wt_cmnt char(30),
rece_seq char(30));


create table psrf (
client_id char(30),
psrf_sts_code char(30));


create table psri (
wt_cmnt char(30),
wt_item char(30));


create table usrdat (
dept_code char(30),
user_code char(30));


create table vivdf (
invs_title char(30),
invs_code char(30),
invs_risk_degree char(30));


create table vpliv (
plan_code char(30),
rate_scale char(30),
invs_code char(30));


create table vpniv (
policy_no char(30),
invs_code char(30));
