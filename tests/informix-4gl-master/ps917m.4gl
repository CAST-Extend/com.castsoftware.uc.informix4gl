
------------------------------------------------------------------------------
--  程式名稱: ps917m.4gl
--  作    者: epf
--  日    期: 104/04/08
--  處理概要: 投資標的約定交易作業
--  重要函式:
------------------------------------------------------------------------------
-- 104/04/08 by epf 用ps901m當基底開發
------------------------------------------------------------------------------

GLOBALS "/prod/def/common.4gl"
GLOBALS "/prod/def/lf.4gl"
GLOBALS "/prod/lib/ar904p0.4gl"
GLOBALS "/prod/sub/ShowMsg.4gl"
GLOBALS "/prod/lib/ap905p0.4gl"
GLOBALS "/prod/lib/ar901p0.4gl"
GLOBALS "/prod/def/hva.4gl"

DATABASE life

    DEFINE p_bell           CHAR                    --> 鈴聲字元
    DEFINE p_space          CHAR(20)                --> 空白
    DEFINE p_keys           CHAR(400)               --> 查詢條件暫存區
    DEFINE p_err            INTEGER                 --> 錯誤訊息
    DEFINE p_total_record   INTEGER                 --> 資料總數
    DEFINE p_current_record INT                     --> 查詢中現在資料筆數

    DEFINE p_udigit         INTEGER                 --> 標的單位小數位數
    DEFINE p_vdigit         INTEGER                 --> 標的金額小數位數

    DEFINE p_sll_total      INTEGER                 --> 賣出項目總數
    DEFINE p_buy_total      INTEGER                 --> 買入項目總數
    DEFINE p_piv_total      INTEGER                 --> 投資標的總數
    DEFINE p_chg_amt        FLOAT                   --> 轉換試算總額（保單幣別）

    DEFINE p_user_dept      CHAR(6)                 --> 處理者部門
    DEFINE p_today          CHAR(9)                 --> 系統日期
    DEFINE p_last_work      CHAR(9)                 --> 前一營業日期
    DEFINE p_new            INTEGER                 --> chah 檔案旗標
    DEFINE p_resp           INTEGER                 --> 中介錯誤代碼

    DEFINE p_pldf           RECORD LIKE pldf.*      --> 險種資料
    DEFINE p_vivdf ARRAY[100] OF RECORD LIKE vivdf.* --> 標的資料

    DEFINE p_sell_flag ARRAY[ 3 ] OF INTEGER        --> 賣出標的類別旗標
    DEFINE p_buy_flag ARRAY[ 3 ] OF INTEGER         --> 買入標的類別旗標
    DEFINE p_sell_sum_amt   FLOAT                   --> 總賣出金額
    DEFINE p_check_amt_ind  SMALLINT                --> 是否檢核總賣出金額指示
    DEFINE p_sell_sum       INTEGER                 --> 賣出標的類別數
    DEFINE p_buy_sum        INTEGER                 --> 買入標的類別數

    DEFINE p_tv RECORD                              --> 名辭資料
             chah_ind  CHAR(18)
    END RECORD

    DEFINE p_ds RECORD
        receive_date    CHAR(9),                    --> 受理日期
        c_desc          CHAR(20),                   --> 幣別中文說明
        po_chg_code        CHAR(10),                --> 約定交易項目代碼
        owner_id        LIKE pocl.client_id,        --> 要保人
        o1_name         LIKE popr.o1_name,
        client_id       LIKE pocl.client_id,
        names           LIKE popr.names,
        new_receive_no      LIKE chah.receive_no        --取消作業之新受理號碼
    END RECORD

    DEFINE p_chah           RECORD LIKE chah.*      --> 投資約定交易資料
    DEFINE p_chap           RECORD LIKE chap.*      --> 投資約定交易匯款資料

    DEFINE p_sll ARRAY[ 100 ] OF RECORD             --> 投資約定交易賣出明細
              invs_code          LIKE chad.invs_code,
              chah_sell_type     LIKE chad.chah_sell_type,
              chah_sell_type_desc  CHAR(10),
              invs_ad_amt        LIKE chad.invs_ad_amt,
              skip_field         CHAR
           END RECORD


    DEFINE p_sll_val ARRAY [100] OF RECORD
              chah_sell_type_desc  CHAR(10)
           END RECORD

    DEFINE p_buy ARRAY[ 100 ] OF RECORD              --> 投資約定交易買入明細
              invs_code          LIKE chad.invs_code,
              invs_ad_perc       LIKE chad.invs_ad_perc
           END RECORD

    DEFINE p_display_flag    SMALLINT                  --插旗顯示專用

    DEFINE p_chah_ind        LIKE chah.chah_ind     --> 1.約定轉換 2.約定提領
    DEFINE p_process_ind     CHAR                   --> 進入功能

-------------------------------------------------------------------------------

MAIN

    OPTIONS
        ERROR LINE LAST,
        PROMPT LINE LAST - 1,
        MESSAGE LINE LAST - 1,
        COMMENT LINE LAST

    DEFER INTERRUPT
    SET LOCK MODE TO WAIT

    LET g_program_id = "ps917m"
    LET p_space = (20 SPACES)
    LET p_bell = ASCII 7

    LET p_display_flag = FALSE
    LET p_chah_ind = "1"
    LET p_check_amt_ind = TRUE

    LET p_today = GetDate( TODAY )
    LET p_last_work = GetLastWorkDate( p_today, 1 )

    LET p_tv.chah_ind = "chah_ind"

    --OPEN FORM ps917m01 FROM "ps917m01" --預設先開啟轉換form
    --DISPLAY FORM ps917m01 ATTRIBUTE (GREEN)

    CALL set_input_form(TRUE)

    CALL ShowLogo()
    CALL JobControl()

    -- 讀取使用者單位代碼

    SELECT dept_code
      INTO p_user_dept
      FROM edp_base:usrdat
     WHERE user_code = g_user

    MENU ""
        BEFORE MENU
            IF NOT CheckAuthority( "C", FALSE ) THEN
                HIDE OPTION "1)新增"
            END IF

            IF NOT CheckAuthority( "U", FALSE ) THEN
                HIDE OPTION "2)取消"
            END IF

            IF NOT CheckAuthority( "D", FALSE ) THEN
                HIDE OPTION "3)修改"
            END IF

            IF NOT CheckAuthority( "Q", FALSE ) THEN
                HIDE OPTION "4)查詢"
            END IF

            DISCONNECT CURRENT

        COMMAND "1)新增"
            CONNECT TO 'life'
            LET p_process_ind = "1"
            CALL appoint_add()
            DISCONNECT CURRENT

        COMMAND "2)取消"
            CONNECT TO 'life'
            LET p_process_ind = "2"
            CALL appoint_cancel()
            DISCONNECT CURRENT

        COMMAND "3)修改"
            CONNECT TO 'life'
            LET p_process_ind = "3"
            CALL appoint_modify()
            DISCONNECT CURRENT

        COMMAND "4)查詢"
            CONNECT TO 'life'
            LET p_process_ind = "4"
            CALL appoint_query()
            DISCONNECT CURRENT

        COMMAND "0)結束"
            EXIT MENU
    END MENU

    CONNECT TO 'life'
    CLOSE FORM ps917m01
    CALL JobControl()

END MAIN

-------------------------------------------------------------------------------
--  函式名稱: show_total_record
--  處理概要: 顯示目前的資料總數
--  輸入參數: (no)
--  輸出參數: (no)
-------------------------------------------------------------------------------

FUNCTION show_total_record()

    DISPLAY p_total_record TO total_record

END FUNCTION            -- show_total_record --

-------------------------------------------------------------------------------
--  函式名稱: show_current_record
--  處理概要: 顯示目前的資料總數
--  輸入參數: (no)
--  輸出參數: (no)
-------------------------------------------------------------------------------

FUNCTION show_current_record()

    DISPLAY p_current_record TO now_record

END FUNCTION            -- show_current_record --

-------------------------------------------------------------------------------
--  函式名稱: display_appoint
--  處理概要: 顯示約定交易資料
--  輸入參數: (no)
--  輸出參數: (no)
-------------------------------------------------------------------------------
FUNCTION display_appoint()

    DISPLAY BY NAME
        p_chah.policy_no, g_polf.po_sts_code,
        p_chah.receive_no, p_ds.receive_date,p_chah.active_ind,
        p_chah.chah_freq, p_chah.chah_ind, p_chah.bgn_date,
        g_polf.currency, p_ds.c_desc,g_polf.basic_plan_code

    DISPLAY p_ds.o1_name,p_ds.names TO o1_name,i1_name
    IF p_process_ind MATCHES '[2]' THEN
       DISPLAY BY NAME p_ds.new_receive_no
    END IF

END FUNCTION            -- display_appoint --


-------------------------------------------------------------------------------
--  函式名稱: display_remit_data
--  處理概要: 顯示約定交易資料
--  輸入參數: (no)
--  輸出參數: (no)
-------------------------------------------------------------------------------
FUNCTION display_remit_data()
    DEFINE f_bank_code    LIKE bank.bank_code
    DEFINE f_bank_name    LIKE bank.bank_name

    LET f_bank_code = p_chap.remit_bank||p_chap.remit_branch

    LET f_bank_name = get_bank_name(f_bank_code)

    DISPLAY BY NAME
        p_chap.chap_disb_type, p_chap.remit_bank,
        p_chap.remit_branch, p_chap.remit_account, p_chap.payee,
        p_chap.payee_e

    DISPLAY f_bank_name TO bank_name

END FUNCTION            -- display_appoint --

-------------------------------------------------------------------------------
--  函式名稱: display_sell
--  處理概要: 顯示賣出資料
--  輸入參數: 第一行指標
--  輸出參數: (no)
-------------------------------------------------------------------------------

FUNCTION display_sell( p )
    DEFINE p, i     INTEGER

    SCROLL sa_17m10.* UP BY 3

    FOR i = 0 TO 2
        IF i + p > p_sll_total THEN
            EXIT FOR
        END IF

        CALL TermMeaning("chah_sell_type",p_sll[i+p].chah_sell_type)
        RETURNING p_sll[i + p].chah_sell_type_desc

        DISPLAY p_sll[ i + p ].* TO sa_17m10[ i + 1 ].*
    END FOR

    DISPLAY p_sll_total TO total_sell_record

END FUNCTION            -- display_sell --

-------------------------------------------------------------------------------
--  函式名稱: display_buy
--  處理概要: 顯示買入資料
--  輸入參數: 第一行指標
--  輸出參數: (no)
-------------------------------------------------------------------------------

FUNCTION display_buy( p )
    DEFINE p, i     INTEGER

    SCROLL sa_17m11.* UP BY 3

    FOR i = 0 TO 2
        IF i + p > p_buy_total THEN
            EXIT FOR
        END IF

        DISPLAY p_buy[ i + p ].* TO sa_17m11[ i + 1 ].*
    END FOR

    DISPLAY p_buy_total TO total_buy_record

END FUNCTION            -- display_buy --

-------------------------------------------------------------------------------
--  函式名稱: ask_policy_no
--  處理概要: 詢問保單號碼或受理號碼（試算時使用）
--  輸入參數: (no)
--  輸出參數: TRUE -> o.k.    FALSE -> give up
-------------------------------------------------------------------------------

FUNCTION ask_policy_no()

    DEFINE f_int  SMALLINT   --陣列註標
    DEFINE f_po_chg_code  LIKE apit.po_chg_code

    CLEAR FORM
    MESSAGE " 請輸入保單號碼或受理號碼。Esc: 接受，End: 放棄"

    LET INT_FLAG = FALSE
    LET f_po_chg_code = " "

    INPUT BY NAME p_chah.policy_no,p_chah.receive_no
    ATTRIBUTE (RED, REVERSE, UNDERLINE)
        AFTER FIELD policy_no
            IF NOT FIELD_TOUCHED( policy_no ) OR LENGTH(p_chah.policy_no) = 0 THEN
               CONTINUE INPUT
            END IF

            -- 檢核保單號碼檢查碼
            IF NOT CheckPolicyNo( p_chah.policy_no ) THEN
                ERROR " 您輸入的保單號碼檢查碼不符，請修正。"
                ATTRIBUTE (RED, UNDERLINE)
                NEXT FIELD policy_no
            END IF

            -- 讀取受理資料（以最大的受理號碼為準）
            SQL
                SELECT FIRST 1 a.po_chg_rece_no, a.po_chg_rece_date,b.po_chg_code
                  INTO $p_chah.receive_no, $p_ds.receive_date,$p_ds.po_chg_code
                  FROM apdt a, apit b
                 WHERE a.po_chg_rece_no = b.po_chg_rece_no
                   AND a.policy_no = $p_chah.policy_no
                   AND a.po_chg_sts_code MATCHES "[2]"
                   AND b.po_chg_code IN ('73','74')
                 ORDER BY 1 DESC
            END SQL

            IF SQLCA.SQLCODE = NOTFOUND THEN
                ERROR " 您輸入的保單沒有受理資料。"
                ATTRIBUTE (RED, UNDERLINE)
                NEXT FIELD policy_no
            END IF

        AFTER FIELD receive_no
            IF NOT FIELD_TOUCHED( receive_no ) OR LENGTH(p_chah.receive_no) = 0 THEN
               CONTINUE INPUT
            END IF

            -- 檢核受理狀況
            SELECT a.policy_no, a.po_chg_rece_date,b.po_chg_code
              INTO p_chah.policy_no, p_ds.receive_date,p_ds.po_chg_code
              FROM apdt a, apit b
             WHERE a.po_chg_rece_no = b.po_chg_rece_no
               AND a.po_chg_rece_no = p_chah.receive_no
               AND a.po_chg_sts_code MATCHES "[2]"
               AND b.po_chg_code IN ('73','74')
            IF STATUS = NOTFOUND THEN
                ERROR " 您輸入的受理號碼不存在或者狀況不符，請修正。"
                ATTRIBUTE (RED, UNDERLINE)
                NEXT FIELD receive_no
            END IF

    END INPUT

    MESSAGE ""

    IF INT_FLAG OR (p_chah.policy_no IS NULL AND p_chah.receive_no IS NULL)
    THEN
        RETURN FALSE
    END IF

    IF p_process_ind = '2' THEN
       LET p_ds.new_receive_no = p_chah.receive_no
    END IF

    DISPLAY BY NAME p_chah.policy_no, p_chah.receive_no, p_ds.receive_date

    -- 檢核投資交易是否符合轉換條件
    IF NOT check_invest_condition() THEN
        RETURN FALSE
    END IF

    -- 讀取資料
    CALL loading_data()

    -- 讀取保單資料並檢核條件
    RETURN check_policy_condition()

END FUNCTION            -- ask_policy_no --
{--todo 可拿掉
-------------------------------------------------------------------------------
--  函式名稱: get_policy_no
--  處理概要: 詢問保單號碼與受理號碼（列印時使用）
--  輸入參數: (no)
--  輸出參數: TRUE -> o.k.    FALSE -> give up
-------------------------------------------------------------------------------

FUNCTION get_policy_no()
    DEFINE f_chah   RECORD LIKE chah.*

    CLEAR FORM
    MESSAGE " 請輸入保單號碼或受理號碼。Esc: 接受，End: 放棄"

    LET INT_FLAG = FALSE
    INPUT BY NAME p_chah.policy_no, p_chah.receive_no
    ATTRIBUTE (RED, REVERSE, UNDERLINE)
        AFTER FIELD policy_no
            IF NOT FIELD_TOUCHED( policy_no ) OR p_chah.policy_no IS NULL THEN
                CONTINUE INPUT
            END IF

            IF NOT CheckPolicyNo( p_chah.policy_no ) THEN
                ERROR " 您輸入的保單號碼檢查碼不符，請修正。"
                ATTRIBUTE (RED, UNDERLINE)
                NEXT FIELD policy_no
            END IF
    END INPUT

    MESSAGE ""

    IF INT_FLAG OR (LENGTH(p_chah.policy_no)=0 AND LENGTH(p_chah.receive_no)=0)
    THEN
       RETURN FALSE
    END IF

    -- 檢核投資變更資料是否存在
    CASE
    WHEN LENGTH(p_chah.policy_no)>0 AND LENGTH(p_chah.receive_no)>0
        SELECT *
          INTO f_chah.*
          FROM chah
         WHERE policy_no = p_chah.policy_no
           AND receive_no = p_chah.receive_no

        LET p_err = STATUS

    WHEN LENGTH(p_chah.policy_no) = 0
        SELECT *
          INTO f_chah.*
          FROM chah
         WHERE receive_no = p_chah.receive_no

        LET p_err = STATUS

    WHEN LENGTH(p_chah.receive_no) = 0
        SELECT *
          INTO f_chah.*
          FROM chah
         WHERE policy_no = p_chah.policy_no
           AND receive_no = (
                SELECT MAX( receive_no )
                  FROM chah
                 WHERE policy_no = p_chah.policy_no
                )

        LET p_err = STATUS

    END CASE

    IF p_err = NOTFOUND THEN
        ERROR " 查無約定交易資料！"
        ATTRIBUTE (RED, UNDERLINE)
        RETURN FALSE
    END IF

    LET p_chah.* = f_chah.*

    CALL loading_data()

    RETURN TRUE

END FUNCTION            -- get_policy_no --
}
-------------------------------------------------------------------------------
--  函式名稱: select_data
--  處理概要: 資料選擇（查詢使用）
--  輸入參數: (no)
--  輸出參數: TRUE -> o.k.    FALSE -> give up
-------------------------------------------------------------------------------

FUNCTION select_data()
    DEFINE cmd      CHAR(500)

    -- 輸入條件

    CLEAR FORM
    MESSAGE " 請輸入條件。Esc: 接受，End: 放棄"

    LET INT_FLAG = FALSE
    CONSTRUCT BY NAME p_keys
           ON policy_no, receive_no, chah_ind,active_ind, bgn_date,chah_freq
    ATTRIBUTE (RED, REVERSE, UNDERLINE)
       BEFORE CONSTRUCT
          IF p_process_ind = '2' THEN
             DISPLAY BY NAME p_ds.new_receive_no
             DISPLAY BY NAME p_chah.policy_no
             ATTRIBUTE (RED, REVERSE, UNDERLINE)
             CASE p_ds.po_chg_code
                WHEN '73'
                   LET p_chah_ind = '1'
                   DISPLAY p_chah_ind TO chah_ind ATTRIBUTE (RED, REVERSE, UNDERLINE)
                WHEN '74'
                   LET p_chah_ind = '2'
                   DISPLAY p_chah_ind TO chah_ind ATTRIBUTE (RED, REVERSE, UNDERLINE)
             END CASE
             EXIT CONSTRUCT
          END IF
       --取消修改跳過這些欄位
       BEFORE FIELD chah_ind
          IF p_process_ind MATCHES '[3]' THEN
             IF FGL_LASTKEY()=FGL_KEYVAL("UP") OR FGL_LASTKEY()=FGL_KEYVAL("LEFT") THEN
                NEXT FIELD PREVIOUS
             ELSE
                NEXT FIELD NEXT
             END IF
          END IF
       BEFORE FIELD active_ind
          IF p_process_ind MATCHES '[3]' THEN
             IF FGL_LASTKEY()=FGL_KEYVAL("UP") OR FGL_LASTKEY()=FGL_KEYVAL("LEFT") THEN
                NEXT FIELD PREVIOUS
             ELSE
                NEXT FIELD NEXT
             END IF
          END IF
       BEFORE FIELD bgn_date
          IF p_process_ind MATCHES '[3]' THEN
             IF FGL_LASTKEY()=FGL_KEYVAL("UP") OR FGL_LASTKEY()=FGL_KEYVAL("LEFT") THEN
                NEXT FIELD PREVIOUS
             ELSE
                NEXT FIELD NEXT
             END IF
          END IF
       BEFORE FIELD chah_freq
          IF p_process_ind MATCHES '[3]' THEN
             IF FGL_LASTKEY()=FGL_KEYVAL("UP") OR FGL_LASTKEY()=FGL_KEYVAL("LEFT") THEN
                NEXT FIELD PREVIOUS
             ELSE
                NEXT FIELD NEXT
             END IF
          END IF

       AFTER CONSTRUCT
          IF INT_FLAG THEN
             EXIT CONSTRUCT
          END IF

          --新增取消修改 必須輸入保單號碼受理號碼擇一 查詢不用
          IF p_process_ind MATCHES '[123]' THEN
             LET p_chah.policy_no = GET_FLDBUF(chah.policy_no)
             LET p_chah.receive_no = GET_FLDBUF(chah.receive_no)
             IF NOT INT_FLAG THEN
                IF LENGTH(p_chah.policy_no) = 0 AND LENGTH(p_chah.receive_no) = 0 THEN
                   ERROR "請至少輸入保單號碼或受理號碼!!" ATTRIBUTE(RED,RED,UNDERLINE)
                   CONTINUE CONSTRUCT
                END IF
             END IF
          END IF

          IF p_process_ind = '4' THEN
             IF NOT FIELD_TOUCHED(chah.*) THEN
                ERROR "請至少輸入一項條件!!" ATTRIBUTE(RED,RED,UNDERLINE)
                CONTINUE CONSTRUCT
             END IF
          END IF

    END CONSTRUCT

    MESSAGE ""
    IF INT_FLAG THEN
       LET INT_FLAG = FALSE
       RETURN FALSE
    END IF

    -- 檢核有無資料
    LET p_total_record = 0
    LET cmd = "SELECT COUNT(*) FROM chah WHERE ", p_keys CLIPPED
    PREPARE tt_pre FROM cmd
    DECLARE tt_crs CURSOR FOR tt_pre
    OPEN tt_crs
    FETCH tt_crs INTO p_total_record
    CLOSE tt_crs
    FREE tt_pre

    IF NOT p_total_record THEN
        ERROR " 查無符合條件的資料存在。"
        ATTRIBUTE (RED, UNDERLINE)
        RETURN FALSE
    END IF

    RETURN TRUE

END FUNCTION            -- select_data --

-------------------------------------------------------------------------------
--  函式名稱: appoint_add
--  處理概要: 轉換試算
--  輸入參數: (no)
--  輸出參數: (no)
-------------------------------------------------------------------------------

FUNCTION appoint_add()
    DEFINE ans CHAR
    DEFINE f_err SMALLINT
    DEFINE f_bpqi    RECORD LIKE bpqi.*

    INITIALIZE p_chah TO NULL

    IF NOT ask_policy_no() THEN
        RETURN
    END IF

    IF NOT initialization( FALSE ) THEN
        RETURN
    END IF

    CALL display_appoint()
    CALL display_sell( 1 )
    IF p_chah_ind = "1" THEN
       CALL display_buy( 1 )
    ELSE
       CALL display_remit_data()
    END IF

    -- 編輯與存檔
LABEL re_input:
    IF editor_appoint() THEN
        LET p_chah.process_user = g_user
        LET p_chah.process_date = p_today
        LET p_chah.process_time = TIME

        CALL display_appoint() --顯示更新後的買賣日

        WHENEVER ERROR CONTINUE

        DISPLAY "1:重回修正  2:暫存  3:過帳  其它:離開 " AT 22, 2
                   ATTRIBUTE (YELLOW, UNDERLINE)
        PROMPT "請選擇功能" FOR CHAR ans

        IF ans = "1" THEN
           GOTO re_input
        END IF

        IF ans = "2" THEN
           -- 先檢查承辦人
           SELECT *
             INTO f_bpqi.*
             FROM bpqi
            WHERE receive_no = p_chah.receive_no
           IF f_bpqi.access_user <> g_user THEN
              ERROR " 您非案件 Owner 無法作業！"
              ATTRIBUTE (RED, UNDERLINE)
              RETURN
           END IF
           -- BPM 案件行政授權訊息顯示
           CALL ps996_auth_display( p_chah.receive_no, 0 )
           ERROR "資料已暫存"
        END IF
        IF ans = "3" THEN
           -- -- BPM 案件檢核行政授權檢核
           IF NOT ps996_auth_check( p_chah.receive_no, "44", 0 ) THEN
              RETURN
           END IF
        END IF

        IF ans MATCHES "[23]" THEN
           BEGIN WORK

           IF p_new THEN
               CALL inserting_chah()
               CALL inserting_chad()
           ELSE
               CALL updating_chah()
               CALL deleting_chad()
               CALL inserting_chad()
           END IF

           IF NOT ps917_check_dup_appoint_sell(0) THEN
              ROLLBACK WORK
              ERROR " 同一指定日期轉換/提領賣出投資標的重覆！"
              ATTRIBUTE (RED, UNDERLINE)
              RETURN
           END IF

           COMMIT WORK
        END IF

        WHENEVER ERROR STOP

        IF ans = "3" THEN
           CALL saving_approval()



           -- 批寫資料
           -- 列印批註信函 寫入批註信函發單檔

           IF NOT psrd_insert(p_chah.receive_no) THEN
              ERROR " 寫入批註信函有誤"
           END IF

           -- 顯示批寫文字
           CALL query_psrd(p_chah.receive_no)

           PROMPT " 列印批註信函(任意鍵:確認)" FOR CHAR ans
           IF NOT insert_pble(p_chah.policy_no,
                              p_chah.receive_no,
                             'PL') THEN
              --ERROR " 寫入批註信函發單檔有誤"
           END IF

           PROMPT " 列印保單明細表(1.列印 2.轉影像  3.列印及轉影像)" FOR CHAR ans
           LET f_err = TRUE
           CASE ans
              WHEN '1'
                 LET f_err = print_po_only(p_chah.policy_no,p_chah.receive_no,'1')
              WHEN '2'
                 LET f_err = print_po_only(p_chah.policy_no,p_chah.receive_no,'2')
              WHEN '3'
                 LET f_err = print_po_only(p_chah.policy_no,p_chah.receive_no,'1')
                 LET f_err = print_po_only(p_chah.policy_no,p_chah.receive_no,'2')
           END CASE

           IF NOT f_err THEN
              ERROR " 列印保單明細表有誤"
           END IF

            --更新受理狀態 > C 變更完成 > 5 結案
           CALL ap905_update_sts( p_chah.receive_no, "C" )
           CALL ap905_update_sts( p_chah.receive_no, "5" )

           ERROR "資料已過帳"

        END IF

    ELSE
        ERROR " 您放棄新增。" ATTRIBUTE (WHITE, UNDERLINE)
    END IF

END FUNCTION            -- appoint_add --

-------------------------------------------------------------------------------
--  函式名稱: appoint_cancel
--  處理概要: 轉換取消
--  輸入參數: (no)
--  輸出參數: (no)
-------------------------------------------------------------------------------
FUNCTION appoint_cancel()
    DEFINE f_int    INTEGER
    DEFINE f_cancel_ind  INT
    DEFINE cmd      CHAR(500)
    DEFINE i, j     INTEGER
    DEFINE f_err    SMALLINT
    DEFINE ans      CHAR

    INITIALIZE p_chah TO NULL
    LET f_cancel_ind = FALSE

    IF NOT ask_policy_no() THEN
        RETURN
    END IF

    IF NOT select_data() THEN
        RETURN
    END IF

    LET cmd = "SELECT count(*) FROM chah WHERE ",
               p_keys CLIPPED,
              " AND active_ind = '0'"
    PREPARE cancel_total_record_pre FROM cmd
    EXECUTE cancel_total_record_pre INTO p_total_record
    FREE cancel_total_record_pre

    -- 讀取資料

    LET cmd = "SELECT * FROM chah WHERE ", p_keys CLIPPED,
              " AND active_ind = '0'",
              " ORDER BY chah_seq DESC"

    PREPARE cancel_pre FROM cmd
    DECLARE cancel_crs SCROLL CURSOR FOR cancel_pre

    OPEN cancel_crs
    FETCH cancel_crs INTO p_chah.*

    IF STATUS = NOTFOUND THEN
       ERROR " 查無符合條件的資料存在。"
       ATTRIBUTE (RED, UNDERLINE)
       RETURN
    END IF

    LET i = 1
    LET j = 1
    LET p_current_record = 1
    CALL loading_data()
    CALL display_appoint()
    CALL display_sell( i )
    IF p_chah.chah_ind = "1" THEN
       CALL display_buy( j )
    ELSE
       CALL display_remit_data()
    END IF

    CALL show_current_record()
    CALL show_total_record()

    MENU "選擇"
        COMMAND KEY ( F3, CONTROL-N, "N" ) "N)下一筆"
            FETCH NEXT cancel_crs INTO p_chah.*
            LET i = 1
            LET j = 1
            IF SQLCA.SQLCODE <> NOTFOUND THEN
               LET p_current_record = p_current_record + 1
            END IF
            CALL loading_data()
            CALL display_appoint()
            CALL display_sell( i )
            IF p_chah.chah_ind = "1" THEN
               CALL display_buy( j )
            ELSE
               CALL display_remit_data()
            END IF
            CALL show_current_record()
            CALL show_total_record()

        COMMAND KEY ( F4, CONTROL-P, "P" ) "P)上一筆"
            FETCH PREVIOUS cancel_crs INTO p_chah.*
            LET i = 1
            LET j = 1
            IF SQLCA.SQLCODE <> NOTFOUND THEN
               LET p_current_record = p_current_record - 1
            END IF
            CALL loading_data()
            CALL display_appoint()
            CALL display_sell( i )
            IF p_chah.chah_ind = "1" THEN
               CALL display_buy( j )
            ELSE
               CALL display_remit_data()
            END IF
            CALL show_current_record()
            CALL show_total_record()

        COMMAND KEY ( F5 , "3") "3)取消"
            LET f_cancel_ind = TRUE
            EXIT MENU

        COMMAND KEY ( INTERRUPT, "0" ) "0)結束"
            EXIT MENU
    END MENU

    CLOSE cancel_crs
    FREE cancel_pre

    IF f_cancel_ind THEN
       IF AnswerYes( " 是否取消?" ) THEN
           -- BPM 案件檢核行政授權檢核
           IF NOT ps996_auth_check( p_ds.new_receive_no, "44", 0 ) THEN
              RETURN
           END IF

           CALL saving_cancel()

           -- 批寫資料
           -- 列印批註信函 寫入批註信函發單檔
           IF NOT psrd_insert(p_ds.new_receive_no) THEN
              ERROR " 寫入批註信函有誤"
           END IF

           -- 顯示批寫文字
           CALL query_psrd(p_ds.new_receive_no)

           PROMPT " 列印批註信函(任意鍵:確認)" FOR CHAR ans
           IF NOT insert_pble(p_chah.policy_no,
                              p_ds.new_receive_no,
                             'PL') THEN
              --ERROR " 寫入批註信函發單檔有誤"
           END IF

           PROMPT " 列印保單明細表(1.列印 2.轉影像  3.列印及轉影像)" FOR CHAR ans
           LET f_err = TRUE
           CASE ans
              WHEN '1'
                 LET f_err = print_po_only(p_chah.policy_no,p_ds.new_receive_no,'1')
              WHEN '2'
                 LET f_err = print_po_only(p_chah.policy_no,p_ds.new_receive_no,'2')
              WHEN '3'
                 LET f_err = print_po_only(p_chah.policy_no,p_ds.new_receive_no,'1')
                 LET f_err = print_po_only(p_chah.policy_no,p_ds.new_receive_no,'2')
           END CASE

           IF NOT f_err THEN
              ERROR " 列印保單明細表有誤"
           END IF

           --更新受理狀態 > C 變更完成 > 5 結案
           CALL ap905_update_sts( p_ds.new_receive_no, "C" )
           CALL ap905_update_sts( p_ds.new_receive_no, "5" )

           ERROR " 資料已取消。"
       ELSE
           ERROR " 您放棄取消。" ATTRIBUTE (WHITE, UNDERLINE)
       END IF
    ELSE
       LET INT_FLAG = FALSE
    END IF

END FUNCTION            -- appoint_cancel --

-------------------------------------------------------------------------------
--  函式名稱: appoint_modify
--  處理概要: 轉換修改
--  輸入參數: (no)
--  輸出參數: (no)
-------------------------------------------------------------------------------

FUNCTION appoint_modify()
    DEFINE f_cnt    INT
    DEFINE f_modify_ind SMALLINT
    DEFINE cmd      CHAR(500)
    DEFINE i, j     INTEGER

    INITIALIZE p_chah TO NULL

    IF NOT select_data() THEN
        RETURN
    END IF

    LET cmd = "SELECT count(*) FROM chah WHERE ",
               p_keys CLIPPED,
              " AND active_ind = '0'"
    PREPARE modify_total_record_pre FROM cmd
    EXECUTE modify_total_record_pre INTO p_total_record
    FREE modify_total_record_pre

    -- 讀取資料

    LET cmd = "SELECT * FROM chah WHERE ",
               p_keys CLIPPED,
              " AND active_ind = '0'",
              " ORDER BY chah_seq DESC"

    PREPARE modify_pre FROM cmd
    DECLARE modify_crs SCROLL CURSOR FOR modify_pre

    OPEN modify_crs
    FETCH modify_crs INTO p_chah.*

    IF STATUS = NOTFOUND THEN
       ERROR " 查無符合條件的資料存在。"
       ATTRIBUTE (RED, UNDERLINE)
       RETURN
    END IF

    LET i = 1
    LET j = 1
    LET p_current_record = 1
    CALL loading_data()
    CALL display_appoint()
    CALL display_sell( i )
    IF p_chah.chah_ind = "1" THEN
       CALL display_buy( j )
    ELSE
       CALL display_remit_data()
    END IF

    CALL show_current_record()
    CALL show_total_record()

    MENU "選擇"
        COMMAND KEY ( F3, CONTROL-N, "N" ) "N)下一筆"
            FETCH NEXT modify_crs INTO p_chah.*
            LET i = 1
            LET j = 1
            IF SQLCA.SQLCODE <> NOTFOUND THEN
               LET p_current_record = p_current_record + 1
            END IF
            CALL loading_data()
            CALL display_appoint()
            CALL display_sell( i )
            IF p_chah.chah_ind = "1" THEN
               CALL display_buy( j )
            ELSE
               CALL display_remit_data()
            END IF
            CALL show_current_record()
            CALL show_total_record()

        COMMAND KEY ( F4, CONTROL-P, "P" ) "P)上一筆"
            FETCH PREVIOUS modify_crs INTO p_chah.*
            LET i = 1
            LET j = 1
            IF SQLCA.SQLCODE <> NOTFOUND THEN
               LET p_current_record = p_current_record - 1
            END IF
            CALL loading_data()
            CALL display_appoint()
            CALL display_sell( i )
            IF p_chah.chah_ind = "1" THEN
               CALL display_buy( j )
            ELSE
               CALL display_remit_data()
            END IF
            CALL show_current_record()
            CALL show_total_record()

        COMMAND KEY ( F5 , "3") "3)修改"
            LET f_modify_ind = TRUE
            EXIT MENU

        COMMAND KEY ( INTERRUPT, "0" ) "0)結束"
            EXIT MENU
    END MENU

    CLOSE modify_crs
    FREE modify_pre

    IF f_modify_ind THEN
       CALL display_appoint()
       CALL display_sell( 1 )
       IF p_chah.chah_ind = "1" THEN
          CALL display_buy( j )
       ELSE
          CALL display_remit_data()
       END IF

       LET f_cnt = 0
       SELECT COUNT(*)
         INTO f_cnt
         FROM chah a,chlh b
        WHERE a.chah_seq = b.chah_seq
          AND a.chah_seq = p_chah.chah_seq

       IF f_cnt > 0 THEN
           ERROR " 本筆約定交易的投資交易已開始，無法修改！"
           ATTRIBUTE (RED, UNDERLINE)
           RETURN
       END IF

       IF editor_appoint() THEN
          LET p_chah.process_user = g_user
          LET p_chah.process_date = p_today
          LET p_chah.process_time = TIME
       END IF

       IF AnswerYes( " 確認修改?" ) THEN
           CALL saving_modify()
           ERROR " 資料已修改。"
       ELSE
           ERROR " 您放棄修改。" ATTRIBUTE (WHITE, UNDERLINE)
       END IF
    END IF

END FUNCTION            -- appoint_modify --

-------------------------------------------------------------------------------
--  函式名稱: appoint_query
--  處理概要: 轉換查詢
--  輸入參數: (no)
--  輸出參數: (no)
-------------------------------------------------------------------------------

FUNCTION appoint_query()
    DEFINE cmd      CHAR(500)
    DEFINE i, j     INTEGER

    IF NOT select_data() THEN
        RETURN
    END IF

    -- 讀取資料

    LET cmd = "SELECT * FROM chah WHERE ", p_keys CLIPPED,
              " ORDER BY chah_seq DESC"

    PREPARE query_pre FROM cmd
    DECLARE query_crs SCROLL CURSOR FOR query_pre

    OPEN query_crs
    FETCH query_crs INTO p_chah.*

    LET i = 1
    LET j = 1
    LET p_current_record = 1
    CALL loading_data()
    CALL display_appoint()
    CALL display_sell( i )
    IF p_chah_ind = "1" THEN
       CALL display_buy( j )
    ELSE
       CALL display_remit_data()
    END IF

    CALL show_current_record()
    CALL show_total_record()

    MENU "選擇"
        COMMAND KEY ( F3, CONTROL-N, "N" ) "N)下一筆"
            FETCH NEXT query_crs INTO p_chah.*
            LET i = 1
            LET j = 1
            IF SQLCA.SQLCODE <> NOTFOUND THEN
               LET p_current_record = p_current_record + 1
            END IF
            CALL loading_data()
            CALL display_appoint()
            CALL display_sell( i )
            IF p_chah_ind = "1" THEN
               CALL display_buy( j )
            ELSE
               CALL display_remit_data()
            END IF
            CALL show_current_record()
            CALL show_total_record()

        COMMAND KEY ( F4, CONTROL-P, "P" ) "P)上一筆"
            FETCH PREVIOUS query_crs INTO p_chah.*
            LET i = 1
            LET j = 1
            IF SQLCA.SQLCODE <> NOTFOUND THEN
               LET p_current_record = p_current_record - 1
            END IF
            CALL loading_data()
            CALL display_appoint()
            CALL display_sell( i )
            IF p_chah_ind = "1" THEN
               CALL display_buy( j )
            ELSE
               CALL display_remit_data()
            END IF
            CALL show_current_record()
            CALL show_total_record()

        COMMAND KEY ( F9, CONTROL-F, "F" ) "F)第一筆"
            FETCH FIRST query_crs INTO p_chah.*
            LET i = 1
            LET j = 1
            LET p_current_record = 1
            CALL loading_data()
            CALL display_appoint()
            CALL display_sell( i )
            IF p_chah_ind = "1" THEN
               CALL display_buy( j )
            ELSE
               CALL display_remit_data()
            END IF
            CALL show_current_record()
            CALL show_total_record()

        COMMAND KEY ( F10, CONTROL-E, "E" ) "E)最末筆"
            FETCH LAST query_crs INTO p_chah.*
            LET i = 1
            LET j = 1
            LET p_current_record = p_total_record
            CALL loading_data()
            CALL display_appoint()
            CALL display_sell( i )
            IF p_chah_ind = "1" THEN
               CALL display_buy( j )
            ELSE
               CALL display_remit_data()
            END IF
            CALL show_current_record()
            CALL show_total_record()

        COMMAND "1)賣出下頁"
            IF i + 3 <= p_sll_total THEN
                LET i = i + 3
                CALL display_sell( i )
            END IF

        COMMAND "2)賣出上頁"
            IF i - 3 > 0 THEN
                LET i = i - 3
                CALL display_sell( i )
            END IF

        COMMAND "3)買入下頁"
            IF j + 3 <= p_buy_total THEN
                LET j = j + 3
                IF p_chah_ind = "1" THEN
                   CALL display_buy( j )
                END IF
            END IF

        COMMAND "4)買入上頁"
            IF j - 3 > 0 THEN
                LET j = j - 3
                IF p_chah_ind = "1" THEN
                   CALL display_buy( j )
                END IF
            END IF

        COMMAND KEY ( INTERRUPT, "0" ) "0)結束"
            EXIT MENU
    END MENU

    CLOSE query_crs
    FREE query_pre

END FUNCTION            -- appoint_query --

-------------------------------------------------------------------------------
--  函式名稱: psrd_insert
--  處理概要: 批寫資料寫入列印
--  輸入參數: (no)
--  輸出參數: (no)
-------------------------------------------------------------------------------

FUNCTION psrd_insert(f_receive_no)
    DEFINE f_psrd         RECORD LIKE psrd.*
    DEFINE f_cnt,i        SMALLINT
    DEFINE f_total        SMALLINT
    DEFINE f_title        CHAR(28) --固定28碼
    DEFINE yy,mm,dd       SMALLINT
    DEFINE yyy            CHAR(3)
    DEFINE mmm,ddd        CHAR(2)
    DEFINE f_receive_no   LIKE chah.receive_no

    DEFINE p_msg       ARRAY[200] OF RECORD
           wt_item  LIKE psrd.wt_item,
           wt_cmnt  LIKE psrd.wt_cmnt
           END RECORD

    INITIALIZE f_psrd.* TO NULL
    INITIALIZE p_msg TO NULL

    CALL SeparateYMD(p_chah.process_date) RETURNING yy,mm,dd
    LET yyy = yy USING "&&&"
    LET mmm = mm USING "&&"
    LET ddd = dd USING "&&"

    --第一行
    LET f_cnt = 1
    LET p_msg[f_cnt].wt_item = '10'
    SELECT replace(replace(replace(replace(replace(
           wt_cmnt,'xxxxxxxxxxxx',p_chah.policy_no),
           'xxxxxxxx',f_receive_no),'yyy',yyy),'mm',mmm)
           ,'dd',ddd)
      INTO p_msg[f_cnt].wt_cmnt
      FROM psri
     WHERE wt_item = p_msg[f_cnt].wt_item

    CALL cut_string_cmnt(p_msg[f_cnt].wt_cmnt,28)
               RETURNING p_msg[f_cnt].wt_cmnt
    --第二行
    LET f_cnt = f_cnt + 1
    LET p_msg[f_cnt].wt_item = '42'
    SELECT replace(replace(replace(
           wt_cmnt,'YYY',yyy),'MM',mmm)
           ,'DD',ddd)
      INTO p_msg[f_cnt].wt_cmnt
      FROM psri
     WHERE wt_item = p_msg[f_cnt].wt_item

    CALL cut_string_cmnt(p_msg[f_cnt].wt_cmnt,28)
               RETURNING p_msg[f_cnt].wt_cmnt

    --寫入約定項目資料
    LET f_cnt = f_cnt + 1
    LET p_msg[f_cnt].wt_item = 'U8'
    IF p_process_ind = '2' THEN
       LET p_msg[f_cnt].wt_cmnt = "取消投資標的"
    ELSE
       LET p_msg[f_cnt].wt_cmnt = "約定投資標的"
    END IF
    IF p_chah.chah_ind = "1" THEN
       LET p_msg[f_cnt].wt_cmnt = p_msg[f_cnt].wt_cmnt CLIPPED,"轉換"
    ELSE
       LET p_msg[f_cnt].wt_cmnt = p_msg[f_cnt].wt_cmnt CLIPPED,"提領"
    END IF
    IF p_chah.chah_freq = 0 THEN
       LET p_msg[f_cnt].wt_cmnt =
       p_msg[f_cnt].wt_cmnt CLIPPED,"：",p_chah.bgn_date[1,3],"年"
                                        ,p_chah.bgn_date[5,6],"月"
                                        ,p_chah.bgn_date[8,9],"日"
    ELSE
       LET p_msg[f_cnt].wt_cmnt =
       p_msg[f_cnt].wt_cmnt CLIPPED,"：",p_chah.bgn_date[1,3],"年"
                                        ,p_chah.bgn_date[5,6],"月"
                                        ,p_chah.bgn_date[8,9],"日起每"
       CASE p_chah.chah_freq
          WHEN 1
             LET p_msg[f_cnt].wt_cmnt = p_msg[f_cnt].wt_cmnt CLIPPED,
                                        "月"
          WHEN 3
             LET p_msg[f_cnt].wt_cmnt = p_msg[f_cnt].wt_cmnt CLIPPED,
                                        "季"
          WHEN 6
             LET p_msg[f_cnt].wt_cmnt = p_msg[f_cnt].wt_cmnt CLIPPED,
                                        "半年"
          WHEN 12
             LET p_msg[f_cnt].wt_cmnt = p_msg[f_cnt].wt_cmnt CLIPPED,
                                        "年"
       END CASE
       LET p_msg[f_cnt].wt_cmnt = p_msg[f_cnt].wt_cmnt CLIPPED,
                                  "之",p_chah.bgn_date[8,9],"日"
    END IF
    --取消作業增加原受理號碼
    IF p_process_ind = '2' THEN
       LET p_msg[f_cnt].wt_cmnt = p_msg[f_cnt].wt_cmnt CLIPPED,
                                  "(原受理號碼:",p_chah.receive_no,")"
    END IF
    --寫入投資標的轉出資料
    LET f_cnt = f_cnt + 1
    LET p_msg[f_cnt].wt_item = 'U8'
    LET p_msg[f_cnt].wt_cmnt = "約定賣出投資標的"

    FOR i = 1 TO p_sll_total
       LET f_cnt = f_cnt + 1
       LET p_msg[f_cnt].wt_item = 'U8'
       SELECT invs_title
         INTO f_title
         FROM vivdf
        WHERE invs_code = p_sll[i].invs_code

       LET p_msg[f_cnt].wt_cmnt = p_msg[f_cnt].wt_cmnt CLIPPED,
                                  p_sll[i].invs_code,f_title
       IF p_sll[i].chah_sell_type = "1" THEN
          LET p_msg[f_cnt].wt_cmnt = p_msg[f_cnt].wt_cmnt ,"  ", --固定隔兩碼
                                     "轉出金額 ",p_sll[i].invs_ad_amt USING "#######&.&&元"
       ELSE
          LET p_msg[f_cnt].wt_cmnt = p_msg[f_cnt].wt_cmnt ,"  ", --固定隔兩碼
                                     "全部結清 "
       END IF

    END FOR

    --寫入投資標的買入資料
    IF p_chah.chah_ind = "1" THEN
       LET f_cnt = f_cnt + 1
       LET p_msg[f_cnt].wt_item = 'U8'
       LET p_msg[f_cnt].wt_cmnt = "約定買入投資標的"
       FOR i = 1 TO p_buy_total
          LET f_cnt = f_cnt + 1
          LET p_msg[f_cnt].wt_item = 'U8'

          SELECT invs_title
            INTO f_title
            FROM vivdf
           WHERE invs_code = p_buy[i].invs_code

          LET p_msg[f_cnt].wt_cmnt = p_msg[f_cnt].wt_cmnt CLIPPED,
                                     p_buy[i].invs_code,f_title

          LET p_msg[f_cnt].wt_cmnt = p_msg[f_cnt].wt_cmnt ,"  ",
                                         "轉入比例 ",p_buy[i].invs_ad_perc USING "##&%"

       END FOR
    END IF

    --最後二行
    LET f_cnt = f_cnt + 1
    LET p_msg[f_cnt].wt_item = 'Z1'
    SELECT wt_cmnt
      INTO p_msg[f_cnt].wt_cmnt
      FROM psri
     WHERE wt_item = p_msg[f_cnt].wt_item    
    
    LET f_cnt = f_cnt + 1
    LET p_msg[f_cnt].wt_item = 'Z2'
    SELECT wt_cmnt
      INTO p_msg[f_cnt].wt_cmnt
      FROM psri
     WHERE wt_item = p_msg[f_cnt].wt_item

    LET f_total = f_cnt

    -- 寫入批寫table
    BEGIN WORK
    INSERT INTO psrh VALUES
    (p_chah.policy_no,f_receive_no
    ,' ',' ',g_program_id,g_user,p_chah.process_date)
    IF SQLCA.SQLCODE != 0 THEN
       ROLLBACK WORK
       RETURN FALSE
    END IF

    FOR f_cnt = 1 TO f_total
        IF LENGTH(p_msg[f_cnt].wt_cmnt) > 0 THEN
           INSERT INTO psrd VALUES(f_receive_no,
                                   p_msg[f_cnt].wt_item,
                                   f_cnt,
                                   p_msg[f_cnt].wt_cmnt)
           IF SQLCA.SQLCODE != 0 THEN
              ROLLBACK WORK
              RETURN FALSE
           END IF
        END IF
    END FOR

    COMMIT WORK

    RETURN TRUE

END FUNCTION            -- psrd_insert --

-------------------------------------------------------------------------------
--  函式名稱: editor_appoint
--  處理概要: 轉換作業編輯驅動器
--  輸入參數: (no)
--  輸出參數: TRUE -> saving    FALSE -> give up
-------------------------------------------------------------------------------

FUNCTION editor_appoint()
    DEFINE sw       INTEGER
    DEFINE f_modify_ind SMALLINT   --是否新增過帳

    OPTIONS INSERT KEY F31

    LET sw = 1

    WHILE sw
        CASE sw
           WHEN 1
              DISPLAY " F5:上區 F6:中區 F7:下區 Esc:賣出資料 End:放棄" AT 22, 2
              ATTRIBUTE (YELLOW, UNDERLINE)
           WHEN 2
              IF p_chah_ind = "1" THEN
                 DISPLAY " Del:清除 F5:上區 F6:中區 F7:下區 Esc:買入資料 End:放棄" AT 22, 2
                 ATTRIBUTE (YELLOW, UNDERLINE)
              ELSE
                 DISPLAY " Del:清除 F5:上區 F6:中區 F7:下區 Esc:匯款方式 End:放棄" AT 22, 2
                 ATTRIBUTE (YELLOW, UNDERLINE)
              END IF
           WHEN 3
              DISPLAY "Del:清除 F5:上區 F6:中區 F7:下區 Esc:確認 End:放棄" AT 22, 2
              ATTRIBUTE (YELLOW, UNDERLINE)
        END CASE

        CASE sw
           WHEN 1
               LET sw = edit_header()
           WHEN 2
               LET sw = edit_sw_sell()
           WHEN 3
              IF p_chah_ind = "1" THEN
                 LET sw = edit_sw_buy()
              ELSE
                 LET sw = edit_remit_account()
              END IF
        END CASE

        DISPLAY p_space, p_space, p_space AT 22, 1

        IF NOT sw THEN
           IF INT_FLAG THEN
              LET INT_FLAG = FALSE
              RETURN FALSE
           END IF
           {
           CASE isSave()
              WHEN "1"
                  RETURN TRUE
              WHEN "2"
                  LET sw = 1
              WHEN "3"
                  RETURN FALSE
           END CASE
           }
           RETURN TRUE
        END IF

    END WHILE

END FUNCTION            -- editor_appoint --

-------------------------------------------------------------------------------
--  函式名稱: edit_header
--  處理概要: 表頭編輯
--  輸入參數:
--  輸出參數: 123 -> 上中下區    0 -> give up
-------------------------------------------------------------------------------
FUNCTION edit_header()
    DEFINE sw       INTEGER
    DEFINE help_rt  CHAR
    DEFINE i        SMALLINT

    LET sw = 2
    LET INT_FLAG = FALSE

    INPUT BY NAME
        p_chah.chah_ind, p_chah.bgn_date, p_chah.chah_freq
        WITHOUT DEFAULTS ATTRIBUTE (BLUE, REVERSE, UNDERLINE) HELP 200
        AFTER FIELD chah_ind
           IF LENGTH(p_chah.chah_ind) = 0 THEN
              ERROR "請輸入約定項目" ATTRIBUTE(RED,UNDERLINE)
              NEXT FIELD chah_ind
           END IF
           --重開form
           IF p_chah_ind <> p_chah.chah_ind THEN
              LET p_chah_ind = p_chah.chah_ind
              CALL set_input_form(FALSE)
              CALL display_appoint()
              CALL display_sell( 1 )
              IF p_chah_ind = "1" THEN
                 CALL display_buy( 1 )
              ELSE
                 CALL display_remit_data()
              END IF
           END IF
           IF p_chah.chah_ind = "1" THEN
              --確認受理項目為何
              IF p_ds.po_chg_code <> "73" THEN
                 ERROR "保單沒有受理資料" ATTRIBUTE(RED,UNDERLINE)
                 NEXT FIELD chah_ind
              END IF
           ELSE -- chah_ind = '2'
              IF p_ds.po_chg_code <> "74" THEN
                 ERROR "保單沒有受理資料" ATTRIBUTE(RED,UNDERLINE)
                 NEXT FIELD chah_ind
              END IF
           END IF

        AFTER FIELD bgn_date
           IF LENGTH(p_chah.bgn_date) = 0 THEN
              ERROR "輸入空白" ATTRIBUTE(RED,UNDERLINE)
              NEXT FIELD bgn_date
           END IF
           CALL CheckDate(p_chah.bgn_date) RETURNING p_err,p_chah.bgn_date
           IF NOT p_err THEN
              ERROR "日期格式錯誤" ATTRIBUTE(RED,UNDERLINE)
              NEXT FIELD bgn_date
           END IF

        AFTER FIELD chah_freq
           IF p_chah.chah_freq IS NULL THEN
              ERROR "輸入空白" ATTRIBUTE(RED,UNDERLINE)
              NEXT FIELD chah_freq
           END IF
           IF p_chah.chah_freq <> 0 AND
              p_chah.chah_freq <> 1 AND
              p_chah.chah_freq <> 3 AND
              p_chah.chah_freq <> 6 AND
              p_chah.chah_freq <> 12 THEN
              ERROR "輸入錯誤" ATTRIBUTE(RED,UNDERLINE)
              NEXT FIELD chah_freq
           END IF
           IF p_chah.chah_freq = 0 THEN
              IF p_chah.bgn_date < p_today THEN
                 ERROR "約定日期不可小於系統作業日期" ATTRIBUTE(RED,UNDERLINE)
                 NEXT FIELD bgn_date
              END IF
           END IF

        ON KEY (F5)
           LET sw = 1
           GOTO accept_edit_header

        ON KEY (F6)
           LET sw = 2
           GOTO accept_edit_header
        ON KEY (F7)
           LET sw = 3
           GOTO accept_edit_header

        AFTER INPUT
LABEL accept_edit_header:
           IF INT_FLAG THEN
              EXIT INPUT
           END IF

           IF LENGTH(p_chah.chah_ind) = 0 THEN
              ERROR "請輸入約定項目" ATTRIBUTE(RED,UNDERLINE)
              NEXT FIELD chah_ind
           END IF
           IF LENGTH(p_chah.bgn_date) = 0 THEN
              ERROR "未輸入指定日期" ATTRIBUTE(RED,UNDERLINE)
              NEXT FIELD bgn_date
           END IF

           IF p_chah.chah_ind = "1" THEN
              --確認受理項目為何
              IF p_ds.po_chg_code <> "73" THEN
                 ERROR "保單沒有受理資料" ATTRIBUTE(RED,UNDERLINE)
                 NEXT FIELD chah_ind
              END IF
           ELSE -- chah_ind = '2'
              IF p_ds.po_chg_code <> "74" THEN
                 ERROR "保單沒有受理資料" ATTRIBUTE(RED,UNDERLINE)
                 NEXT FIELD chah_ind
              END IF
           END IF

           IF p_chah.chah_freq IS NULL THEN
              ERROR "未輸入約定交易頻率" ATTRIBUTE(RED,UNDERLINE)
              NEXT FIELD chah_freq
           END IF
           IF p_chah.chah_freq <> 0 AND
              p_chah.chah_freq <> 1 AND
              p_chah.chah_freq <> 3 AND
              p_chah.chah_freq <> 6 AND
              p_chah.chah_freq <> 12 THEN
              ERROR "交易頻率輸入錯誤" ATTRIBUTE(RED,UNDERLINE)
              NEXT FIELD chah_freq
           END IF
           IF p_chah.chah_freq = 0 THEN
              IF p_chah.bgn_date < p_today THEN
                 ERROR "約定日期不可小於系統作業日期" ATTRIBUTE(RED,UNDERLINE)
                 NEXT FIELD bgn_date
              END IF
           END IF

           --更新下次執行日
           CALL ps917_get_next_tr_date()

    END INPUT

    IF INT_FLAG THEN
       LET sw = 0
    END IF

    OPTIONS INSERT KEY F1

    RETURN sw

END FUNCTION            -- edit_header --

-------------------------------------------------------------------------------
--  函式名稱: edit_sw_sell
--  處理概要: 轉換明細（賣出）編輯
--  輸入參數: (no)
--  輸出參數: 2 -> next page    0 -> quit
-------------------------------------------------------------------------------

FUNCTION edit_sw_sell()
    DEFINE ps, rw   INTEGER
    DEFINE sw, i    INTEGER
    DEFINE tmp_amt  INTEGER
    DEFINE exist    SMALLINT

    LET sw = 3
    DISPLAY p_sll_total TO total_sell_record

    OPTIONS INSERT KEY F31

    LET INT_FLAG = FALSE
    CALL SET_COUNT( p_sll_total )

    INPUT ARRAY p_sll WITHOUT DEFAULTS FROM sa_17m10.*
    ATTRIBUTE (BLUE, REVERSE, UNDERLINE)

        BEFORE ROW
            LET ps = ARR_CURR()
            LET rw = SCR_LINE()

        AFTER FIELD invs_code
            IF FIELD_TOUCHED(invs_code) THEN
               LET p_err = exam_sell_investment( ps )
               IF NOT p_err THEN
                   ERROR p_keys CLIPPED ATTRIBUTE (RED, UNDERLINE)
                   NEXT FIELD invs_code
               END IF
            END IF

            IF NOT ps917_check_dup_appoint_sell(ps) THEN
               ERROR " 同一指定日期轉換/提領賣出投資標的重覆！"
               ATTRIBUTE (RED, UNDERLINE)
               NEXT FIELD invs_code
            END IF

        AFTER ROW

            IF INT_FLAG OR NOT FIELD_TOUCHED( sa_17m10.* ) THEN
               CONTINUE INPUT
            END IF

            LET p_err = exam_sell_investment( ps )

            DISPLAY p_sll[ ps ].* TO sa_17m10[ rw ].*
            ATTRIBUTE (BLUE, REVERSE, UNDERLINE)

            IF NOT p_err THEN
                ERROR p_keys CLIPPED ATTRIBUTE (RED, UNDERLINE)
                CONTINUE INPUT
            END IF

        BEFORE INSERT
            IF LENGTH(p_sll[ps-1].invs_code) = 0 AND ps <> 1 THEN
               CANCEL INSERT
            END IF

        AFTER INSERT
            LET p_sll_total = ARR_COUNT()
            DISPLAY p_sll_total TO total_sell_record

        AFTER DELETE
            LET p_sll_total = ARR_COUNT()
            DISPLAY p_sll_total TO total_sell_record

        AFTER FIELD chah_sell_type
            IF LENGTH(p_sll[ps].chah_sell_type) = 0 THEN
               ERROR "輸入空白" ATTRIBUTE (RED, UNDERLINE)
               NEXT FIELD chah_sell_type
            END IF
            IF FIELD_TOUCHED(chah_sell_type) THEN
               IF LENGTH(p_sll[ps].chah_sell_type) = 0 THEN
                  ERROR "輸入空白" ATTRIBUTE (RED, UNDERLINE)
                  NEXT FIELD chah_sell_type
               END IF
            END IF
            CALL TermMeaning("chah_sell_type",p_sll[ps].chah_sell_type)
            RETURNING p_sll[ps].chah_sell_type_desc

            DISPLAY p_sll[ps].chah_sell_type_desc
            TO sa_17m10[rw].chah_sell_type_desc
            ATTRIBUTE(BLUE,REVERSE,UNDERLINE)

            IF p_sll[ps].chah_sell_type = "1" THEN
               NEXT FIELD invs_ad_amt
            ELSE
               LET p_sll[ps].invs_ad_amt = 0
               DISPLAY p_sll[ps].invs_ad_amt
               TO sa_17m10[rw].invs_ad_amt ATTRIBUTE(BLUE,REVERSE,UNDERLINE)
               CALL check_sell_all()
            END IF
        BEFORE FIELD invs_ad_amt
            IF p_sll[ps].chah_sell_type = "2" THEN
               IF FGL_LASTKEY()=FGL_KEYVAL("UP") OR FGL_LASTKEY()=FGL_KEYVAL("LEFT") THEN
                  NEXT FIELD PREVIOUS
               ELSE
                  NEXT FIELD skip_field
               END IF
            END IF

        AFTER FIELD invs_ad_amt
            IF g_polf.currency = "TWD" THEN
               LET tmp_amt = p_sll[ps].invs_ad_amt
               IF round_value(p_sll[ps].invs_ad_amt - tmp_amt,2) <> 0.0 THEN
                  ERROR "台幣計價保單限輸入整數位" ATTRIBUTE(RED,UNDERLINE)
                  NEXT FIELD invs_ad_amt
               END IF
            END IF
            IF p_sll[ps].invs_ad_amt = 0 OR p_sll[ps].invs_ad_amt IS NULL THEN
               ERROR "指定金額不能為 0" ATTRIBUTE(RED,UNDERLINE)
               NEXT FIELD invs_ad_amt
            END IF
{
            IF p_chah_ind = "1" THEN
               CASE g_polf.currency
                  WHEN "TWD"
                     IF p_sll[ps].invs_ad_amt < 2000 THEN
                        ERROR "轉換賣出金額不可小於 TWD 2000" ATTRIBUTE(RED,UNDERLINE)
                        NEXT FIELD invs_ad_amt
                     END IF
                  WHEN "USD"
                     IF p_sll[ps].invs_ad_amt < 100 THEN
                        ERROR "轉換賣出金額不可小於 USD 100" ATTRIBUTE(RED,UNDERLINE)
                        NEXT FIELD invs_ad_amt
                     END IF
                  WHEN "CNY"
                     IF p_sll[ps].invs_ad_amt < 400 THEN
                        ERROR "轉換賣出金額不可小於 CNY 400" ATTRIBUTE(RED,UNDERLINE)
                        NEXT FIELD invs_ad_amt
                     END IF
               END CASE
            END IF
}
        AFTER INPUT
            LABEL accept_edit_sell:
            IF INT_FLAG THEN
               EXIT INPUT
            END IF

            CALL check_sell_all()

            FOR i = 1 TO p_sll_total
               -- 檢核同一保單是否同時作了同基金的約定交易
               IF NOT ps917_check_dup_appoint_sell(i) THEN
                  ERROR " 同一指定日期轉換/提領賣出投資標的",p_sll[i].invs_code,"重覆！"
                  ATTRIBUTE (RED, UNDERLINE)
                  CONTINUE INPUT
               END IF
            END FOR

            IF p_sll_total = 0 THEN
               ERROR "請輸入賣出資料" ATTRIBUTE(RED,UNDERLINE)
               CONTINUE INPUT
            END IF
            IF p_chah_ind = "2" THEN
               LET p_sell_sum_amt = 0
               FOR i = 1 TO p_sll_total
                  LET p_sell_sum_amt = p_sell_sum_amt + p_sll[i].invs_ad_amt
               END FOR
               IF p_check_amt_ind THEN
                  IF p_sell_sum_amt < p_pldf.part_wd_amt_mini THEN
                     ERROR "提領總金額小於限額",p_pldf.part_wd_amt_mini USING "<<<<<&"
                     ,"元" ATTRIBUTE(RED,UNDERLINE)
                     CONTINUE INPUT
                  END IF
               END IF
            END IF
        ON KEY (F5)
            LET sw = 1
            GOTO accept_edit_sell
        ON KEY (F6)
            LET sw = 2
            GOTO accept_edit_sell
        ON KEY (F7)
            LET sw = 3
            GOTO accept_edit_sell

    END INPUT

    OPTIONS INSERT KEY F1

    IF INT_FLAG THEN
       LET sw = 0
    END IF

    RETURN sw

END FUNCTION            -- edit_sw_sell --

-------------------------------------------------------------------------------
--  函式名稱: edit_sw_buy
--  處理概要: 轉換明細（買入）編輯
--  輸入參數: (no)
--  輸出參數: 1 -> prev page    0 -> quit
-------------------------------------------------------------------------------

FUNCTION edit_sw_buy()
    DEFINE ps, rw   INTEGER
    DEFINE sw, i    INTEGER
    DEFINE f_code   LIKE chid.invs_code

    -- 買入編輯

    LET sw = 0
    LET INT_FLAG = FALSE
    CALL SET_COUNT( p_buy_total )
    DISPLAY p_buy_total TO total_record

    INPUT ARRAY p_buy WITHOUT DEFAULTS FROM sa_17m11.*
    ATTRIBUTE (BLUE, REVERSE, UNDERLINE)
        BEFORE ROW
            LET ps = ARR_CURR()
            LET rw = SCR_LINE()

        AFTER DELETE
            LET p_buy_total = ARR_COUNT()
            DISPLAY p_buy_total TO total_buy_record

        BEFORE INSERT
            IF LENGTH(p_buy[ps-1].invs_code) = 0 AND ps <> 1 THEN
               CANCEL INSERT
            END IF

        AFTER INSERT
            LET p_buy_total = ARR_COUNT()
            DISPLAY p_buy_total TO total_buy_record

        AFTER ROW
            IF INT_FLAG OR NOT FIELD_TOUCHED( sa_17m11.* ) THEN
               CONTINUE INPUT
            END IF

        AFTER FIELD invs_code
            IF NOT FIELD_TOUCHED( invs_code ) THEN
                CONTINUE INPUT
            END IF

            IF NOT exam_buy_investment( ps ) THEN
                NEXT FIELD invs_code
            END IF

        AFTER FIELD invs_ad_perc
            IF NOT FIELD_TOUCHED( invs_ad_perc ) OR p_buy[ps].invs_ad_perc = 0
            THEN
                CONTINUE INPUT
            END IF

            LET i = p_buy[ ps ].invs_ad_perc

            IF i MOD 1 != 0 OR i < 5 THEN
                ERROR " 買入異動率必需大於等於 5% 且為 1% 的倍數，請修正。"
                ATTRIBUTE (RED, UNDERLINE)
                NEXT FIELD invs_ad_perc
            END IF

        ON KEY (F5)
            LET sw = 1
            GOTO accept_edit_buy
        ON KEY (F6)
            LET sw = 2
            GOTO accept_edit_buy
        ON KEY (F7)
            LET sw = 3
            GOTO accept_edit_buy

        AFTER INPUT
            LABEL accept_edit_buy:
            IF INT_FLAG THEN
               EXIT INPUT
            END IF

            LET p_buy_total = ARR_COUNT()

            IF NOT chk_and_show_ad_perc( ps - rw + 1 ) THEN
                ERROR " 異動率的總和不為 100%，請修正。"
                ATTRIBUTE (RED, UNDERLINE)
                CONTINUE INPUT
            END IF

            FOR i = 1 TO p_buy_total
                IF NOT check_duplicate_sell( i )
                THEN
                    ERROR " 要買入的投資標的 ", p_buy[i].invs_code CLIPPED,
                          " 與要賣出的重覆，請修正。"
                    ATTRIBUTE (RED, UNDERLINE)
                    NEXT FIELD invs_code
                END IF
            END FOR

    END INPUT

    LET p_buy_total = ARR_COUNT()

    RETURN sw

END FUNCTION            -- edit_sw_buy --

-------------------------------------------------------------------------------
--  函式名稱: chk_and_show_ad_perc
--  處理概要: 檢核異動率是否為百分之百，並調整買入金額因四捨五入所差的值
--  輸入參數: 第一行指標
--  輸出參數: TRUE -> o.k.    FALSE -> error
-------------------------------------------------------------------------------

FUNCTION chk_and_show_ad_perc( p )
    DEFINE p        INTEGER
    DEFINE i, j     INTEGER
    DEFINE f_tot    FLOAT
    DEFINE f_amt    FLOAT

    LET f_tot = 0
    LET f_amt = 0
    LET j = 1

    -- 加總異動金額與百分比並設定買入異動最後一筆的指標

    FOR i = 1 TO p_buy_total
        LET f_tot = f_tot + p_buy[ i ].invs_ad_perc

    END FOR

    -- 檢核異動百分比總和是否為 100%

    IF f_tot = 100 THEN
        RETURN TRUE
    ELSE
        RETURN FALSE
    END IF

END FUNCTION            -- chk_and_show_ad_perc --

-------------------------------------------------------------------------------
--  函式名稱: check_duplicate_invs
--  處理概要: 檢核投資標的是否重覆
--  輸入參數: 指標
--  輸出參數: TRUE -> no    FALSE -> duplicate
-------------------------------------------------------------------------------

FUNCTION check_duplicate_invs( i )
    DEFINE i, j     INTEGER

    FOR j = 1 TO p_buy_total
        IF i != j THEN
            IF p_buy[i].invs_code = p_buy[j].invs_code THEN
                RETURN FALSE
            END IF
        END IF
    END FOR

    RETURN TRUE

END FUNCTION            -- check_duplicate_invs --

-------------------------------------------------------------------------------
--  函式名稱: check_duplicate_sell
--  處理概要: 檢核投資標的買賣是否重覆
--  輸入參數: 指標
--  輸出參數: TRUE -> no    FALSE -> duplicate
-------------------------------------------------------------------------------

FUNCTION check_duplicate_sell( i )
    DEFINE i, j     INTEGER

    FOR j = 1 TO p_sll_total
        IF p_buy[ i ].invs_code = p_sll[ j ].invs_code
        THEN
            RETURN FALSE
        END IF
    END FOR

    RETURN TRUE

END FUNCTION            -- check_duplicate_sell --

-------------------------------------------------------------------------------
--  函式名稱: loading_investment
--  處理概要: 讀取投資標的資料（vpoiv vivdf vpniv）
--  輸入參數: (no)
--  輸出參數: (no)
-------------------------------------------------------------------------------

FUNCTION loading_investment()
    DEFINE i        INTEGER
    DEFINE cmd      CHAR(500)

    INITIALIZE g_vpoiv, g_vpniv, p_vivdf TO NULL

    LET cmd = "SELECT a.*, b.* FROM vpoiv a, vivdf b ",
              "WHERE a.invs_code = b.invs_code ",
              "AND a.policy_no = '", p_chah.policy_no CLIPPED, "' ",
              "AND a.invs_units != 0 "

    LET cmd = cmd CLIPPED, " ORDER BY a.invs_no"

    PREPARE ld_vpoiv_pre FROM cmd
    DECLARE ld_vpoiv_crs CURSOR FOR ld_vpoiv_pre

    LET i = 1
    FOREACH ld_vpoiv_crs INTO g_vpoiv[ i ].*, p_vivdf[ i ].*
        LET i = i + 1
    END FOREACH
    FREE ld_vpoiv_pre

    LET p_piv_total = i - 1

    -- 若為複合投資法之險種則讀取 vpniv
    -- GVA 視vpniv是否調整來調整
    IF p_pldf.invs_avail_type MATCHES "[235]" THEN
        FOR i = 1 TO p_piv_total
            SELECT *
              INTO g_vpniv[ i ].*
              FROM vpniv
             WHERE policy_no = p_chah.policy_no
               AND invs_code = g_vpoiv[ i ].invs_code
        END FOR

    -- 若為一般停泊之險種其 invs_class 由 vpliv 讀取

    ELSE IF p_pldf.invs_avail_type = "4" THEN
        FOR i = 1 TO p_piv_total
            SELECT invs_class
              INTO g_vpniv[ i ].invs_class
              FROM vpliv
             WHERE plan_code = g_polf.basic_plan_code
               AND rate_scale = g_polf.basic_rate_scale
               AND invs_code = g_vpoiv[ i ].invs_code
        END FOR
    ELSE
        FOR i = 1 TO p_piv_total
            LET g_vpniv[ i ].invs_class = "0"
        END FOR
    END IF END IF

END FUNCTION            -- loading_investment --

-------------------------------------------------------------------------------
--  函式名稱: loading_chad
--  處理概要: 讀取變更明細（chad）
--  輸入參數: (no)
--  輸出參數: (no)
-------------------------------------------------------------------------------

FUNCTION loading_chad()
    DEFINE i, j     INTEGER
    DEFINE f_chad   RECORD LIKE chad.*
    DEFINE f_sts    LIKE vivdf.invs_sts_code
    DEFINE f_currency LIKE vivdf.currency
    DEFINE f_buf    CHAR(500)
    DEFINE cmd      CHAR(500)

    INITIALIZE p_sll, p_buy TO NULL

    LET f_buf = "SELECT a.*, b.invs_sts_code, b.currency ",
                "FROM chad a, vivdf b ",
                "WHERE a.invs_code = b.invs_code ",
                "AND a.policy_no = '", p_chah.policy_no CLIPPED, "' ",
                "AND a.receive_no = '", p_chah.receive_no CLIPPED, "'"

    IF p_chah.chah_seq IS NOT NULL OR p_chah.chah_seq <> 0 THEN
       LET f_buf = f_buf CLIPPED ," AND a.chah_seq = ",p_chah.chah_seq
    END IF

    LET cmd = f_buf

    LET cmd = cmd CLIPPED, " ORDER BY a.invs_ad_sub_ind desc,a.invs_code"

    PREPARE ld_chid_pre FROM cmd
    DECLARE ld_chid_crs CURSOR FOR ld_chid_pre

    LET i = 1
    LET j = 1
    LET p_sell_sum_amt = 0
    FOREACH ld_chid_crs INTO f_chad.*, f_sts, f_currency
        IF f_chad.invs_ad_sub_ind = "2" THEN
            IF f_chad.invs_ad_amt IS NOT NULL THEN
               LET p_sell_sum_amt = p_sell_sum_amt + f_chad.invs_ad_amt
            END IF
            LET p_sll[ i ].invs_code = f_chad.invs_code
            LET p_sll[ i ].chah_sell_type = f_chad.chah_sell_type
            LET p_sll[ i ].invs_ad_amt = f_chad.invs_ad_amt
            CALL TermMeaning("chah_sell_type",p_sll[i].chah_sell_type)
            RETURNING p_sll[i].chah_sell_type_desc
            LET i = i + 1
        ELSE
            LET p_buy[ j ].invs_code = f_chad.invs_code
            LET p_buy[ j ].invs_ad_perc = f_chad.invs_ad_perc
            LET j = j + 1
        END IF
    END FOREACH
    FREE ld_chid_pre

    LET p_sll_total = i - 1
    LET p_buy_total = j - 1

    CALL check_sell_all()

END FUNCTION            -- loading_chad --

-------------------------------------------------------------------------------
--  函式名稱: inserting_chad
--  處理概要: 新增變更明細（chid）
--  輸入參數: (no)
--  輸出參數: (no)
-------------------------------------------------------------------------------

FUNCTION inserting_chad()
    DEFINE f_chad   RECORD LIKE chad.*
    DEFINE i        INTEGER

    -- 設定 chid 相同的資料

    LET f_chad.chah_seq = p_chah.chah_seq
    LET f_chad.policy_no = p_chah.policy_no
    LET f_chad.receive_no = p_chah.receive_no
    LET f_chad.invs_ad_perc = 0
    LET f_chad.invs_ad_amt = 0

    -- 賣出存檔

    LET f_chad.invs_ad_sub_ind = "2"

    FOR i = 1 TO p_sll_total
        LET f_chad.invs_code = p_sll[ i ].invs_code
        LET f_chad.chah_sell_type = p_sll[ i ].chah_sell_type
        LET f_chad.invs_ad_amt = p_sll[ i ].invs_ad_amt

        INSERT INTO chad VALUES ( f_chad.* )

        IF STATUS THEN
            LET p_err = STATUS
            ROLLBACK WORK

            CALL ShowMessage( "chad", 1, p_err )
            EXIT PROGRAM
        END IF
    END FOR

    -- 買入存檔

    LET f_chad.invs_ad_sub_ind = "1"
    LET f_chad.chah_sell_type = "0"
    LET f_chad.invs_ad_amt = 0
    LET f_chad.invs_ad_perc = 0

    FOR i = 1 TO p_buy_total
        LET f_chad.invs_code = p_buy[ i ].invs_code
        LET f_chad.invs_ad_perc = p_buy[ i ].invs_ad_perc

        INSERT INTO chad VALUES ( f_chad.* )

        IF STATUS THEN
            LET p_err = STATUS
            ROLLBACK WORK

            CALL ShowMessage( "chad", 1, p_err )
            EXIT PROGRAM
        END IF
    END FOR

END FUNCTION            -- inserting_chad --

-------------------------------------------------------------------------------
--  函式名稱: deleting_chad
--  處理概要: 刪除變更明細（chad）
--  輸入參數: (no)
--  輸出參數: (no)
-------------------------------------------------------------------------------

FUNCTION deleting_chad()

    DELETE FROM chad
     WHERE chah_seq = p_chah.chah_seq

    IF STATUS THEN
        LET p_err = STATUS
        ROLLBACK WORK
        CALL ShowMessage( "chad", 3, p_err )
        EXIT PROGRAM
    END IF

END FUNCTION            -- deleting_chad --

-------------------------------------------------------------------------------
--  函式名稱: inserting_chah
--  處理概要: 新增變更資料（chah）
--  輸入參數: (no)
--  輸出參數: (no)
-------------------------------------------------------------------------------

FUNCTION inserting_chah()

    INSERT INTO chah VALUES ( p_chah.* )

    IF STATUS THEN
        LET p_err = STATUS
        ROLLBACK WORK

        CALL ShowMessage( "chah", 1, p_err )
        EXIT PROGRAM
    ELSE
        LET p_chah.chah_seq = SQLCA.SQLERRD[2]

        IF p_chah_ind ="2" THEN
           LET p_chap.chah_seq = p_chah.chah_seq
           LET p_chap.policy_no = p_chah.policy_no
           LET p_chap.receive_no = p_chah.receive_no

           INSERT INTO chap VALUES(p_chap.*)
           IF STATUS THEN
              LET p_err = STATUS
              ROLLBACK WORK

              CALL ShowMessage( "chap", 1, p_err )
              EXIT PROGRAM
           END IF
        END IF
    END IF

END FUNCTION            -- inserting_chah --

-------------------------------------------------------------------------------
--  函式名稱: updating_chah
--  處理概要: 更新變更資料（chah）
--  輸入參數: (no)
--  輸出參數: (no)
-------------------------------------------------------------------------------

FUNCTION updating_chah()

    UPDATE chah
       SET chah.* = p_chah.*
     WHERE chah_seq = p_chah.chah_seq

    IF STATUS THEN
        LET p_err = STATUS
        ROLLBACK WORK
        CALL ShowMessage( "chah", 2, p_err )
        EXIT PROGRAM
    END IF
    --若更新太多列 一樣有誤
    IF SQLCA.SQLerrd[3] <> 1 THEN
       LET p_err = STATUS
       ROLLBACK WORK
       CALL ShowMessage( "chah", 2, p_err )
       EXIT PROGRAM
    END IF

    DELETE FROM chap
     WHERE chah_seq = p_chap.chah_seq
    --若刪除太多列 一樣有誤
    IF SQLCA.SQLERRD[3] > 1 THEN
       LET p_err = STATUS
       ROLLBACK WORK
       CALL ShowMessage( "chap", 2, p_err )
       EXIT PROGRAM
    END IF

    IF p_chah.chah_ind = "2" THEN
       INSERT INTO chap VALUES(p_chap.*)
       IF STATUS THEN
          LET p_err = STATUS
          ROLLBACK WORK

          CALL ShowMessage( "chap", 2, p_err )
          EXIT PROGRAM
       END IF
    END IF
END FUNCTION            -- updating_chah --

-------------------------------------------------------------------------------
--  函式名稱: loading_data
--  處理概要: 轉換資料讀取
--  輸入參數: (no)
--  輸出參數: (no)
-------------------------------------------------------------------------------

FUNCTION loading_data()
    IF LENGTH(p_chah.chah_ind) > 0 THEN
       LET p_chah_ind = p_chah.chah_ind
    END IF

    CALL set_input_form(FALSE)

    SELECT *
      INTO g_polf.*
      FROM polf
     WHERE policy_no = p_chah.policy_no

    SELECT a.client_id,b.names
      INTO p_ds.owner_id,p_ds.o1_name
      FROM pocl a,clnt b
     WHERE policy_no = p_chah.policy_no
       AND client_ident = "O1"
       AND a.client_id = b.client_id

    SELECT a.client_id,b.names
      INTO p_ds.client_id,p_ds.names
      FROM pocl a,clnt b
     WHERE policy_no = p_chah.policy_no
       AND client_ident = "I1"
       AND a.client_id = b.client_id

    LET p_ds.c_desc = ar901_get_currency( g_polf.currency )

    LET p_vdigit = g_ar901_digit

    SELECT po_chg_rece_date
      INTO p_ds.receive_date
      FROM apdt
     WHERE po_chg_rece_no = p_chah.receive_no

    SELECT *
      INTO p_pldf.*
      FROM pldf
     WHERE plan_code = g_polf.basic_plan_code
       AND rate_scale = g_polf.basic_rate_scale

    IF p_pldf.invs_avail_type MATCHES "[23]" THEN
        LET ar904_invs_class = "1"
    ELSE
        IF p_pldf.invs_avail_type MATCHES "[45]" THEN
           LET ar904_invs_class = "3"
        ELSE
           LET ar904_invs_class = (1 SPACE)
        END IF
    END IF

    IF p_chah.chah_ind = "2" THEN
       CALL loading_chap()
    END IF

    CALL loading_chad()

END FUNCTION            -- loading_data --

-------------------------------------------------------------------------------
--  函式名稱: saving_cancel
--  處理概要: 確認存檔處理
--  輸入參數: (no)
--  輸出參數: (no)
-------------------------------------------------------------------------------

FUNCTION saving_cancel()

    WHENEVER ERROR CONTINUE

    -- 設定 chih 資料

    BEGIN WORK
    UPDATE chah
       SET active_ind = '1'
     WHERE chah_seq = p_chah.chah_seq

    IF STATUS THEN
       LET p_err = STATUS
       ROLLBACK WORK
       CALL ShowMessage( "chah", 2, p_err )
       EXIT PROGRAM
    END IF

    COMMIT WORK

    WHENEVER ERROR STOP

END FUNCTION            -- saving_cancel --

-------------------------------------------------------------------------------
--  函式名稱: saving_modify
--  處理概要: 修改存檔處理
--  輸入參數: (no)
--  輸出參數: (no)
-------------------------------------------------------------------------------

FUNCTION saving_modify()

    WHENEVER ERROR CONTINUE
    BEGIN WORK

    UPDATE chah
       SET chah.* = p_chah.*
     WHERE policy_no = p_chah.policy_no
       AND receive_no = p_chah.receive_no
       AND chah_seq = p_chah.chah_seq

    IF STATUS THEN
        LET p_err = STATUS
        ROLLBACK WORK
        CALL ShowMessage( "chah", 2, p_err )
        EXIT PROGRAM
    END IF


    UPDATE chah
       SET chah.* = p_chah.*
     WHERE policy_no = p_chah.policy_no
       AND receive_no = p_chah.receive_no
       AND chah_seq = p_chah.chah_seq

    CALL deleting_chad()

    CALL inserting_chad()

    COMMIT WORK
    WHENEVER ERROR STOP

END FUNCTION            -- saving_modify --

-------------------------------------------------------------------------------
--  函式名稱: saving_approval
--  處理概要: 過帳完成處理
--  輸入參數: (no)
--  輸出參數: (no)
-------------------------------------------------------------------------------

FUNCTION saving_approval()

    WHENEVER ERROR CONTINUE
    BEGIN WORK

    LET p_chah.active_ind = "0"

    --更新下一執行日
    CALL ps917_get_next_tr_date()

    UPDATE chah
       SET chah.* = p_chah.*
     WHERE policy_no = p_chah.policy_no
       AND receive_no = p_chah.receive_no
       AND chah_seq = p_chah.chah_seq

    IF STATUS THEN
        LET p_err = STATUS
        ROLLBACK WORK
        CALL ShowMessage( "chah", 2, p_err )
        EXIT PROGRAM
    END IF

    COMMIT WORK
    WHENEVER ERROR STOP

END FUNCTION            -- saving_approval --

-------------------------------------------------------------------------------
--  函式名稱: check_invest_condition
--  處理概要: 檢核投資交易是否符合轉換條件
--  輸入參數: (no)
--  輸出參數: TRUE -> o.k.    FALSE -> error
-------------------------------------------------------------------------------

FUNCTION check_invest_condition()
    DEFINE f_chah   RECORD LIKE chah.*
    DEFINE exist    INTEGER

    -- 檢核投資變更資料是否存在
    SELECT *
      INTO f_chah.*
      FROM chah
     WHERE policy_no = p_chah.policy_no
       AND receive_no = p_chah.receive_no

    IF STATUS = NOTFOUND THEN
        LET p_new = TRUE
    ELSE
        IF f_chah.active_ind = " " THEN
            LET p_new = FALSE
            LET p_chah.* = f_chah.*
        ELSE
           CASE f_chah.active_ind
              WHEN "0"
                 ERROR " 本筆資料已過帳！"
                 ATTRIBUTE (RED, UNDERLINE)
              WHEN "1"
                 ERROR " 本筆資料已取消！"
                 ATTRIBUTE (RED, UNDERLINE)
              WHEN "2"
                 ERROR " 本筆資料已完成！"
                 ATTRIBUTE (RED, UNDERLINE)
           END CASE
           RETURN FALSE
        END IF
    END IF

    RETURN TRUE

END FUNCTION            -- check_invest_condition --

-------------------------------------------------------------------------------
--  函式名稱: check_policy_condition
--  處理概要: 讀取保單相關資料，並檢核其狀況是否符合轉換條件
--  輸入參數: (no)
--  輸出參數: TRUE -> o.k.    FALSE -> error
-------------------------------------------------------------------------------

FUNCTION check_policy_condition()

    -- 讀取保單資料並檢核

    SELECT *
      INTO g_polf.*
      FROM polf
     WHERE policy_no = p_chah.policy_no

    IF STATUS = NOTFOUND THEN
       ERROR " 您的保單在保單主檔中不存在！"
       ATTRIBUTE (RED, UNDERLINE)
       RETURN FALSE
    END IF

    IF g_polf.po_sts_code NOT MATCHES "4[247]" THEN
       ERROR " 您的保單狀況不是 42、44 或 47。"
       ATTRIBUTE (RED, UNDERLINE)
       RETURN FALSE
    END IF

    IF g_polf.insurance_type NOT MATCHES "[VNG]" THEN
       ERROR " 您的保單不是變額類保單。"
       ATTRIBUTE (RED, UNDERLINE)
       RETURN FALSE
    END IF

    -- 讀取險種資料

    SELECT *
      INTO p_pldf.*
      FROM pldf
     WHERE plan_code = g_polf.basic_plan_code
       AND rate_scale = g_polf.basic_rate_scale

    --要確認可作約定的險種
    --後補需求確認用pldf.iv_ass_array限制指定交易
    IF p_pldf.invs_avail_type MATCHES "[23]" THEN
        LET ar904_invs_class = "1"
    ELSE
        IF p_pldf.invs_avail_type MATCHES "[45]" THEN
          LET ar904_invs_class = "3"
        ELSE
           LET ar904_invs_class = (1 SPACE)
        END IF
    END IF

    IF p_pldf.iv_ass_array[3,3] = "0" OR
       p_pldf.iv_ass_array[1,1] = "0" THEN
        ERROR " 您的保單主約險種不可辦理約定交易"
        ATTRIBUTE (RED, UNDERLINE)
        RETURN FALSE
    END IF


    IF p_pldf.ivchg_array[3,3] = "0" OR
       p_pldf.ivchg_array[1,1] = "0" THEN
        ERROR " 您的保單主約險種不允許投資標的轉換或提領。"
        ATTRIBUTE (RED, UNDERLINE)
        RETURN FALSE
    END IF

    -- 設定保單幣別

    LET p_ds.c_desc = ar901_get_currency( g_polf.currency )

    LET p_vdigit = g_ar901_digit

    RETURN TRUE

END FUNCTION            -- check_policy_condition --

-------------------------------------------------------------------------------
--  函式名稱: initialization
--  處理概要: 設定轉換相關資料之初值
--  輸入參數: 重置選項
--  輸出參數: TRUE -> o.k.    FALSE -> give up
-------------------------------------------------------------------------------

FUNCTION initialization( f_reset )
    DEFINE f_reset  INTEGER

    IF f_reset OR p_new THEN
       LET p_chah.chah_seq = 0
       LET p_chah.currency = g_polf.currency
       LET p_chah.active_ind = " "
       INITIALIZE p_chap.* TO NULL
       INITIALIZE p_sll TO NULL
       INITIALIZE p_buy TO NULL
    END IF

    CALL display_appoint()

    CALL loading_investment()

    LET p_chah.process_date = p_today
    LET p_chah.process_user = g_user

    LET p_sell_sum_amt = 0

    RETURN TRUE

END FUNCTION            -- initialization --

-------------------------------------------------------------------------------
--  函式名稱: exam_sell_investment
--  處理概要: 檢核轉出之投資標的
--  輸入參數: 指標
--  輸出參數: TRUE -> o.k.    FALSE -> error
-------------------------------------------------------------------------------

FUNCTION exam_sell_investment( i )
    DEFINE i, j     INTEGER

    FOR j = 1 TO p_sll_total
       IF i != j THEN
          IF p_sll[i].invs_code = p_sll[j].invs_code THEN
              LET p_keys = " 您輸入的投資標的代碼重覆，請修正。"
              RETURN FALSE
          END IF
       END IF
    END FOR

    IF NOT ar904_check_invs( p_chah.policy_no, p_sll[ i ].invs_code ) THEN
       LET p_keys = " 您輸入的投資標的不存在或者不在允許轉換範圍，請修正。"
       RETURN FALSE
    END IF

    RETURN TRUE

END FUNCTION            -- exam_sell_investment --

-------------------------------------------------------------------------------
--  函式名稱: exam_buy_investment
--  處理概要: 檢核轉入之投資標的
--  輸入參數: 指標
--  輸出參數: TRUE -> o.k.    FALSE -> error
-------------------------------------------------------------------------------

FUNCTION exam_buy_investment( i )
    DEFINE i        INTEGER
    DEFINE f_vivrk RECORD LIKE vivrk.*
    DEFINE f_id    LIKE clnt.client_id
    DEFINE f_err   SMALLINT
    DEFINE f_err_msg   CHAR(40)
    DEFINE f_buy_risk_degree LIKE vivdf.invs_risk_degree

    IF NOT check_duplicate_invs( i ) THEN
        ERROR " 您輸入的投資標的代碼重覆，請修正。"
        ATTRIBUTE (RED, UNDERLINE)
        RETURN FALSE
    END IF

    IF NOT check_duplicate_sell( i ) THEN
        ERROR " 您要買入的投資標的與要賣出的重覆，請修正。"
        ATTRIBUTE (RED, UNDERLINE)
        RETURN FALSE
    END IF

    IF NOT ar904_check_invs( p_chah.policy_no, p_buy[ i ].invs_code ) THEN
        ERROR " 您輸入的投資標的不存在或者不在允許轉換範圍，請修正。"
        ATTRIBUTE (RED, UNDERLINE)
        RETURN FALSE
    END IF

    IF ar904_shutting IS NOT NULL AND ar904_shutting != " "
       AND p_ds.receive_date > ar904_shutting THEN

       ERROR " 您輸入的投資標的已停止販售，不得買入，請修正。"
       ATTRIBUTE (RED, UNDERLINE)
       RETURN FALSE

    END IF

    --檢查投資風險等級
    LET f_id = " "
    SELECT client_id
      INTO f_id
      FROM pocl
     WHERE client_ident = 'O1'
       AND policy_no = p_chah.policy_no
    IF STATUS = NOTFOUND THEN
       ERROR " 保單要保人不存在。" ATTRIBUTE (RED, UNDERLINE)
       RETURN FALSE
    END IF
    INITIALIZE f_vivrk.* TO NULL
    CALL iv993p_risk_id(f_id) RETURNING f_err,f_vivrk.risk_suit_seq
                                         ,f_vivrk.risk_suit_ind
                                         ,f_err_msg,f_vivrk.invs_risk_degree
    --如果有風險屬性
    IF f_err THEN
        LET f_buy_risk_degree = " "
        SELECT invs_risk_degree
          INTO f_buy_risk_degree
          FROM vivdf
         WHERE invs_code = p_buy[ i ].invs_code
       IF f_buy_risk_degree > f_vivrk.invs_risk_degree THEN
           ERROR " 投資風險屬性不可購買本投資標的，請修正。"
           ATTRIBUTE (RED, UNDERLINE)
           RETURN FALSE
       END IF
    END IF

    RETURN TRUE

END FUNCTION            -- exam_buy_investment --

-------------------------------------------------------------------------------
--  函式名稱: set_input_form
--  處理概要: 設定轉入標的資料
--  輸入參數: 指標
--  輸出參數: (no)
-------------------------------------------------------------------------------
FUNCTION set_input_form(f_new)
   DEFINE  f_new   SMALLINT
   IF f_new THEN
      OPEN FORM ps917m01 FROM "ps917m01"
      OPEN FORM ps917m02 FROM "ps917m02"
   END IF
   IF p_chah_ind = "1" THEN
      DISPLAY FORM ps917m01 ATTRIBUTE (GREEN)
   ELSE
      DISPLAY FORM ps917m02 ATTRIBUTE (GREEN)
   END IF

   CALL ShowLogo()
END FUNCTION

-------------------------------------------------------------------------------
--  函式名稱: edit_remit_account
--  處理概要: 匯款資料編輯
--  輸入參數: (no)
--  輸出參數: (no)
-------------------------------------------------------------------------------
FUNCTION edit_remit_account()
    DEFINE f_bksw RECORD LIKE bksw.*
    DEFINE f_kval   INTEGER
    DEFINE f_bank_code  LIKE bksw.bank_code
    DEFINE f_bank_name  LIKE bank.bank_name
    DEFINE sw       INTEGER
    DEFINE f_cnt    SMALLINT

    -- 編輯處理
    LET INT_FLAG = FALSE

    INPUT BY NAME p_chap.chap_disb_type,p_chap.remit_bank,p_chap.remit_branch,
                  p_chap.remit_account,p_chap.payee,p_chap.payee_e
        WITHOUT DEFAULTS ATTRIBUTE (BLUE, REVERSE, UNDERLINE) HELP 201

        AFTER FIELD chap_disb_type
           IF p_chap.chap_disb_type = "0" THEN
              SELECT names
                 INTO p_chap.payee
                 FROM clnt
                WHERE client_id = p_ds.owner_id

              DISPLAY BY NAME p_chap.payee
              IF p_new THEN
                 NEXT FIELD NEXT
              END IF
           END IF
           IF p_chap.chap_disb_type MATCHES '[12]' THEN
              INITIALIZE p_chap.remit_bank,p_chap.remit_branch,
                 p_chap.remit_account,p_chap.payee,p_chap.payee_e TO NULL
              DISPLAY BY NAME p_chap.chap_disb_type,p_chap.remit_bank,p_chap.remit_branch,
                 p_chap.remit_account,p_chap.payee,p_chap.payee_e

              CASE p_chap.chap_disb_type
                 WHEN '1'
                    IF g_polf.currency = "TWD" THEN
                       LET f_cnt = 0
                       SELECT COUNT(*)
                         INTO f_cnt
                         FROM psra
                        WHERE client_id = p_ds.owner_id
                          AND psra_sts_code = '0'
                       IF NOT f_cnt THEN
                          ERROR " 無有效匯款約定帳戶" ATTRIBUTE(RED,UNDERLINE)
                          NEXT FIELD chap_disb_type
                       END IF
                    ELSE
                       LET f_cnt = 0
                       SELECT COUNT(*)
                         INTO f_cnt
                         FROM psrf
                        WHERE client_id = p_ds.owner_id
                          AND psrf_sts_code = '0'
                       IF NOT f_cnt THEN
                          ERROR " 無有效匯款約定帳戶" ATTRIBUTE(RED,UNDERLINE)
                          NEXT FIELD chap_disb_type
                       END IF
                    END IF
                 WHEN '2'
                    -- 保單面匯款約定帳戶
                    IF g_polf.currency = "TWD" THEN
                       ERROR " 保單幣別有誤" ATTRIBUTE(RED,UNDERLINE)
                       CONTINUE INPUT
                    ELSE
                       LET f_cnt = 0
                       SELECT COUNT(*)
                         INTO f_cnt
                         FROM pofb
                        WHERE client_id = p_ds.owner_id
                          AND policy_no = p_chah.policy_no
                       IF NOT f_cnt THEN
                          ERROR " 無有效匯款約定帳戶" ATTRIBUTE(RED,UNDERLINE)
                          NEXT FIELD chap_disb_type
                       END IF
                    END IF
              END CASE


              IF p_chap.chap_disb_type = "2" THEN
                 IF g_polf.currency = "TWD" THEN
                    ERROR "保單幣別有誤" ATTRIBUTE(RED,UNDERLINE)
                    NEXT FIELD chap_disb_type
                 END IF
                 LET f_cnt = 0
                 SELECT COUNT(*)
                   INTO f_cnt
                   FROM pofb
                  WHERE client_id = p_ds.owner_id
                    AND policy_no = p_chah.policy_no
                 IF NOT f_cnt THEN
                    ERROR " 無有效匯款約定帳戶" ATTRIBUTE(RED,UNDERLINE)
                    CONTINUE INPUT
                 END IF
              END IF
           END IF

        BEFORE FIELD payee
            IF p_chap.chap_disb_type NOT MATCHES "[12]" THEN
               SELECT names
                 INTO p_chap.payee
                 FROM clnt
                WHERE client_id = p_ds.owner_id

               DISPLAY BY NAME p_chap.payee
            END IF

        BEFORE FIELD payee_e
            IF p_chap.chap_disb_type MATCHES "[12]" THEN
               IF FGL_LASTKEY()=FGL_KEYVAL("UP") OR FGL_LASTKEY()=FGL_KEYVAL("LEFT") THEN
                  NEXT FIELD PREVIOUS
               ELSE
                  NEXT FIELD NEXT
               END IF
            END IF
            IF p_chap.chap_disb_type ="0" THEN
               IF g_polf.currency = "TWD" THEN
                  IF FGL_LASTKEY()=FGL_KEYVAL("UP") OR FGL_LASTKEY()=FGL_KEYVAL("LEFT") THEN
                     NEXT FIELD PREVIOUS
                  ELSE
                     NEXT FIELD NEXT
                  END IF
               END IF
            END IF

        AFTER FIELD payee_e
            CALL exam_chinese( p_chap.payee_e, LENGTH( p_chap.payee_e ) )
            RETURNING p_err

            IF p_err THEN
                ERROR " 受款人英文姓名中含有中文字元，請修正。"
                ATTRIBUTE (RED, UNDERLINE)
                NEXT FIELD payee_e
            END IF
        BEFORE FIELD remit_bank
            IF p_chap.chap_disb_type MATCHES "[12]" THEN
               IF FGL_LASTKEY()=FGL_KEYVAL("UP") OR FGL_LASTKEY()=FGL_KEYVAL("LEFT") THEN
                  NEXT FIELD PREVIOUS
               ELSE
                  NEXT FIELD NEXT
               END IF
            END IF

        BEFORE FIELD remit_branch
            IF p_chap.chap_disb_type MATCHES "[12]" THEN
               IF FGL_LASTKEY()=FGL_KEYVAL("UP") OR FGL_LASTKEY()=FGL_KEYVAL("LEFT") THEN
                  NEXT FIELD PREVIOUS
               ELSE
                  NEXT FIELD NEXT
               END IF
            ELSE
               IF g_polf.currency <> "TWD" THEN
                  LET p_chap.remit_branch = "0000"
                  DISPLAY BY NAME p_chap.remit_branch ATTRIBUTE(BLUE,REVERSE,UNDERLINE)
               END IF
            END IF

        BEFORE FIELD remit_account
            IF p_chap.chap_disb_type MATCHES "[12]" THEN
               IF FGL_LASTKEY()=FGL_KEYVAL("UP") OR FGL_LASTKEY()=FGL_KEYVAL("LEFT") THEN
                  NEXT FIELD PREVIOUS
               ELSE
                  NEXT FIELD NEXT
               END IF
            END IF

        AFTER FIELD remit_bank
            IF LENGTH(p_chap.remit_bank) = 0 THEN
               CONTINUE INPUT
            END IF

        AFTER FIELD remit_branch
            LET f_bank_code = p_chap.remit_bank || p_chap.remit_branch
            LET f_bank_name = get_bank_name( f_bank_code )
            IF LENGTH(f_bank_name) = 0 THEN
               ERROR " 銀行代碼不存在" ATTRIBUTE (RED, UNDERLINE)
               NEXT FIELD remit_bank
            END IF
            SELECT *
              FROM bank
             WHERE bank_code = f_bank_code
               AND bank_use_ind = 'N'
            IF STATUS = NOTFOUND THEN
               ERROR " 銀行代碼無效" ATTRIBUTE (RED, UNDERLINE)
               NEXT FIELD remit_bank
            END IF
            DISPLAY f_bank_name TO bank_name

        ON KEY(F5)
            LET sw = 1
            EXIT INPUT
        ON KEY(F6)
            LET sw = 2
            EXIT INPUT
        ON KEY(F7)
            LET sw = 3
            EXIT INPUT

        AFTER INPUT
            IF INT_FLAG THEN
               LET INT_FLAG = FALSE
               LET sw = 0
               RETURN sw
            END IF
            IF p_chap.chap_disb_type MATCHES "[0]" THEN
               LET p_chap.payee_id = p_ds.owner_id
               IF g_polf.currency = "TWD" THEN
                  CALL chkRemitAcct( p_chap.remit_bank, p_chap.remit_branch,
                                 p_chap.remit_account )
                  RETURNING p_err, p_keys

                  IF p_err THEN
                      ERROR p_keys CLIPPED
                      ATTRIBUTE (RED, UNDERLINE)
                      NEXT FIELD remit_bank
                  END IF
               ELSE
                  SELECT *
                    INTO f_bksw.*
                    FROM bksw
                   WHERE bank_code = f_bank_code
                     AND bank_use_ind = "Y"

                  IF STATUS = NOTFOUND THEN
                      ERROR " 銀行代碼不存在或者已停用，請檢核。"
                      ATTRIBUTE (RED, UNDERLINE)
                      NEXT FIELD remit_bank
                  END IF

                  LET p_chap.swift_code = f_bksw.swift_code
                  LET p_chap.bank_name_e = f_bksw.bank_name_e
                  LET f_bank_name = get_bank_name( p_chap.remit_bank )
                  INITIALIZE p_chap.bank_address_e TO NULL

                  DISPLAY f_bank_name TO bank_name

                  IF f_bksw.payee_en_ind = "Y" THEN
                      IF p_chap.payee_e IS NULL OR p_chap.payee_e = " " THEN
                          ERROR " 此帳號必需輸入受款人英文姓名，請修正。"
                          ATTRIBUTE (RED, UNDERLINE)
                          NEXT FIELD payee_e
                      END IF
                  END IF

                  IF p_chap.remit_account IS NULL OR p_chap.remit_account = " " THEN
                      ERROR " 匯款帳號必需輸入，請修正。"
                      NEXT FIELD remit_account
                  END IF

                  CALL chk_foreignacct( '1' , p_chap.swift_code , p_chap.remit_account )
                  RETURNING p_err, p_keys, p_keys
                  IF p_err THEN
                      ERROR p_keys CLIPPED
                      ATTRIBUTE (RED, UNDERLINE)
                      NEXT FIELD remit_bank
                  END IF
               END IF
            ELSE --p_chap.chap_disb_type = [12]
               CASE p_chap.chap_disb_type
                  WHEN '1'
                     IF g_polf.currency = "TWD" THEN
                        LET f_cnt = 0
                        SELECT COUNT(*)
                          INTO f_cnt
                          FROM psra
                         WHERE client_id = p_ds.owner_id
                           AND psra_sts_code = '0'
                        IF NOT f_cnt THEN
                           ERROR " 無有效匯款約定帳戶" ATTRIBUTE(RED,UNDERLINE)
                           CONTINUE INPUT
                        END IF
                     ELSE
                        LET f_cnt = 0
                        SELECT COUNT(*)
                          INTO f_cnt
                          FROM psrf
                         WHERE client_id = p_ds.owner_id
                           AND psrf_sts_code = '0'
                        IF NOT f_cnt THEN
                           ERROR " 無有效匯款約定帳戶" ATTRIBUTE(RED,UNDERLINE)
                           CONTINUE INPUT
                        END IF
                     END IF
                  WHEN '2'
                     -- 保單面匯款約定帳戶
                     IF g_polf.currency = "TWD" THEN
                        ERROR " 保單幣別有誤" ATTRIBUTE(RED,UNDERLINE)
                        CONTINUE INPUT
                     ELSE
                        LET f_cnt = 0
                        SELECT COUNT(*)
                          INTO f_cnt
                          FROM pofb
                         WHERE client_id = p_ds.owner_id
                           AND policy_no = p_chah.policy_no
                        IF NOT f_cnt THEN
                           ERROR " 無有效匯款約定帳戶" ATTRIBUTE(RED,UNDERLINE)
                           CONTINUE INPUT
                        END IF
                     END IF
               END CASE
            END IF

            LET sw = 0

    END INPUT
    MESSAGE ""

    LET INT_FLAG = FALSE
    RETURN sw

END FUNCTION            -- edit_remit_account --
-------------------------------------------------------------------------------
--  函式名稱: get_bank_name
--  處理概要: 讀取銀行名稱
--  輸入參數: 銀行代碼
--  輸出參數: 銀行名稱
-------------------------------------------------------------------------------

FUNCTION get_bank_name( f_code )
    DEFINE f_code   LIKE bank.bank_code
    DEFINE f_name   LIKE bank.bank_name

    SELECT bank_name
      INTO f_name
      FROM bank
     WHERE bank_code = f_code

    IF STATUS THEN
        INITIALIZE f_name TO NULL
    END IF

    RETURN f_name

END FUNCTION            -- get_bank_name --

-------------------------------------------------------------------------------
--  函式名稱: loading_chap
--  處理概要: 讀取約定交易匯款資料（chap）
--  輸入參數: (no)
--  輸出參數: (no)
-------------------------------------------------------------------------------

FUNCTION loading_chap()

    SELECT *
      INTO p_chap.*
      FROM chap
     WHERE policy_no = p_chah.policy_no
       AND receive_no = p_chah.receive_no
       AND chah_seq = p_chah.chah_seq

END FUNCTION            -- loading_chap --

-------------------------------------------------------------------------------
--  函式名稱: check_sell_all
--  處理概要: 檢核是否有全部結清標的
--  輸入參數: (no)
--  輸出參數: (no)
-------------------------------------------------------------------------------

FUNCTION check_sell_all()
    DEFINE i, j     INTEGER

    LET p_check_amt_ind = TRUE

    FOR i = 1 TO p_sll_total
       IF p_sll[i].chah_sell_type = "2" THEN
          LET p_check_amt_ind = FALSE
       END IF
    END FOR

END FUNCTION            -- check_composite_sell --

-------------------------------------------------------------------------------
--  函式名稱: query_psrd
--  處理概要: show自動批寫資料
--  輸入參數: (no)
--  輸出參數: (no)
-------------------------------------------------------------------------------

FUNCTION query_psrd(f_receive_no)
    DEFINE i, tot   INTEGER
    DEFINE f_temp   LIKE psrd.wt_cmnt
    DEFINE f_receive_no  LIKE chah.receive_no

    DEFINE f_dat ARRAY[ 200 ] OF RECORD
        wt_item     LIKE psrd.wt_item,
        wt_cmnt1    CHAR(60),
        wt_cmnt2    CHAR(60),
        wt_cmnt3    CHAR(60)                END RECORD

    -- 讀取批寫資料

    DECLARE psrd_crs CURSOR FOR
     SELECT wt_item, wt_cmnt,rece_seq
       FROM psrd
      WHERE receive_no = f_receive_no
      ORDER BY 3

    LET i = 1
    FOREACH psrd_crs INTO f_dat[ i ].wt_item, f_temp
        CALL cut_string( f_temp, LENGTH( f_temp ), 60 )
        RETURNING f_dat[ i ].wt_cmnt1, f_temp

        CALL cut_string( f_temp, LENGTH( f_temp ), 60 )
        RETURNING f_dat[ i ].wt_cmnt2, f_dat[ i ].wt_cmnt3

        LET i = i + 1

        IF i > 200 THEN
            EXIT FOREACH
        END IF
    END FOREACH

    LET tot = i - 1

    IF NOT tot THEN
        ERROR " 該受理號碼查無批寫資料。"
        ATTRIBUTE (RED, UNDERLINE)
        RETURN
    END IF

    -- 顯示查詢資料

    OPEN WINDOW ap001m12 AT 7, 5 WITH FORM "ap001m12"
    ATTRIBUTE ( GREEN, FORM LINE FIRST )

    CALL SET_COUNT( tot )
    DISPLAY ARRAY f_dat TO sa_01mc0.*

    CLOSE WINDOW ap001m12

END FUNCTION            -- query_psrd --
-------------------------------------------------------------------------------
--  函式名稱: ps917_get_next_tr_date
--  處理概要: 取得下一自動執行日
--  輸入參數: (no)
--  輸出參數: (no)
-------------------------------------------------------------------------------
FUNCTION ps917_get_next_tr_date()
   DEFINE i    SMALLINT

   --更新下次執行日
   LET i = 0
   LET p_chah.auto_tr_date = p_chah.bgn_date
   WHILE TRUE
      LET i = i + 1
      IF p_chah.auto_tr_date < p_chah.process_date THEN
         LET p_chah.auto_tr_date = AddMonth(p_chah.auto_tr_date,p_chah.chah_freq)
      ELSE
         EXIT WHILE
      END IF
      IF i > 10 THEN
         EXIT WHILE
      END IF
   END WHILE

END FUNCTION

-------------------------------------------------------------------------------
--  函式名稱: ps917_check_dup_appoint_sell
--  處理概要: 檢查是否有同一指定日賣出同一標的
--  輸入參數: ps 賣出標的index (若輸入0 全檢查)
--  輸出參數: (no)
--  修    改: 開發中途調整指定日 從年月日判別 改為 月日 判別
-------------------------------------------------------------------------------
FUNCTION ps917_check_dup_appoint_sell(ps)
   DEFINE exist               SMALLINT
   DEFINE ps                  INT
   DEFINE bgn_idx,end_idx,i   INT
   DEFINE f_bgn_date_month_day CHAR(5)

   IF ps < 0 THEN
      RETURN FALSE
   END IF

   -- 檢核同一保單是否同時作了同基金的約定交易
   -- 輸入0 全賣出標日都檢查
   IF ps = 0 THEN
      LET bgn_idx = 1
      LET end_idx = p_sll_total
   ELSE
      LET bgn_idx = ps
      LET end_idx = ps
   END IF

   LET exist = 0
   LET f_bgn_date_month_day = p_chah.bgn_date[5,9]
   FOR i = bgn_idx TO end_idx
      SELECT COUNT(*)
        INTO exist
        FROM chah a,chad b
       WHERE a.policy_no = p_chah.policy_no
         AND a.chah_seq = b.chah_seq
         AND a.bgn_date[5,9] = f_bgn_date_month_day
         AND a.receive_no <> p_chah.receive_no
         AND b.invs_ad_sub_ind = "2"  --賣出
         AND b.invs_code = p_sll[i].invs_code
         AND a.active_ind = "0" --已過帳
   END FOR

   IF exist THEN
      RETURN FALSE
   END IF

   RETURN TRUE

END FUNCTION