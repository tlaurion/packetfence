--
-- PacketFence SQL schema upgrade from X.X.X to X.Y.Z
--

-- Update acct_update PROCEDURE

DROP PROCEDURE IF EXISTS acct_update;
DELIMITER /
CREATE PROCEDURE acct_update(
  IN p_timestamp datetime,
  IN p_framedipaddress varchar(15),
  IN p_acctsessiontime int(12),
  IN p_acctinputoctets bigint(20),
  IN p_acctoutputoctets bigint(20),
  IN p_acctuniqueid varchar(64),
  IN p_acctsessionid varchar(64),
  IN p_username varchar(64),
  IN p_realm varchar(64),
  IN p_nasipaddress varchar(15),
  IN p_nasportid varchar(15),
  IN p_nasporttype varchar(32),
  IN p_acctauthentic varchar(32),
  IN p_connectinfo_start varchar(50),
  IN p_calledstationid varchar(50),
  IN p_callingstationid varchar(50),
  IN p_servicetype varchar(32),
  IN p_framedprotocol varchar(32),
  IN p_acctstatustype varchar(25)
)
BEGIN
  DECLARE Previous_Input_Octets bigint(20);
  DECLARE Previous_Output_Octets bigint(20);
  DECLARE Previous_Session_Time int(12);
  DECLARE Previous_AcctUpdate_Time datetime;

  # Collect traffic previous values in the radacct table
  SELECT acctinputoctets, acctoutputoctets, acctsessiontime, acctupdatetime
    INTO Previous_Input_Octets, Previous_Output_Octets, Previous_Session_Time, Previous_AcctUpdate_Time
    FROM radacct
    WHERE acctuniqueid = p_acctuniqueid 
    AND (acctstoptime IS NULL OR acctstoptime = 0);

  IF (Previous_Session_Time IS NULL AND p_acctsessiontime IS NOT NULL) THEN
    # Set values to 0 when no previous records
    SET Previous_Session_Time = 0;
    SET Previous_Input_Octets = 0;
    SET Previous_Output_Octets = 0;
    SET Previous_AcctUpdate_Time = p_timestamp;
    # If there is no open session for this, open one.
    INSERT INTO radacct 
           (
            acctsessionid,      acctuniqueid,       username, 
            realm,              nasipaddress,       nasportid, 
            nasporttype,        acctstarttime,      
            acctupdatetime,     acctsessiontime,    acctauthentic, 
            connectinfo_start,  acctinputoctets, 
            acctoutputoctets,   calledstationid,    callingstationid, 
            servicetype,        framedprotocol, 
            framedipaddress
           ) 
    VALUES 
        (
            p_acctsessionid,        p_acctuniqueid,     p_username,
            p_realm,                p_nasipaddress,     p_nasportid,
            p_nasporttype,          date_sub(p_timestamp, INTERVAL p_acctsessiontime SECOND ), 
            p_timestamp,            p_acctsessiontime , p_acctauthentic,
            p_connectinfo_start,    p_acctinputoctets,
            p_acctoutputoctets,     p_calledstationid, p_callingstationid,
            p_servicetype,          p_framedprotocol,
            p_framedipaddress
        );
  ELSE 
    # Update record with new traffic
    UPDATE radacct SET
        framedipaddress = p_framedipaddress,
        acctsessiontime = p_acctsessiontime,
        acctinputoctets = p_acctinputoctets,
        acctoutputoctets = p_acctoutputoctets,
        acctupdatetime = p_timestamp,
        acctinterval = timestampdiff( second, Previous_AcctUpdate_Time,  p_timestamp  )
    WHERE acctuniqueid = p_acctuniqueid 
    AND (acctstoptime IS NULL OR acctstoptime = 0);

  END IF;

  # Update record with new traffic
  UPDATE radacct SET
    framedipaddress = p_framedipaddress,
    acctsessiontime = p_acctsessiontime,
    acctinputoctets = p_acctinputoctets,
    acctoutputoctets = p_acctoutputoctets,
    acctupdatetime = p_timestamp,
    acctinterval = timestampdiff( second, Previous_AcctUpdate_Time,  p_timestamp  )
    WHERE acctuniqueid = p_acctuniqueid 
    AND (acctstoptime IS NULL OR acctstoptime = 0);

  # Create new record in the log table
  INSERT INTO radacct_log
   (acctsessionid, username, nasipaddress,
    timestamp, acctstatustype, acctinputoctets, acctoutputoctets, acctsessiontime)
  VALUES
   (p_acctsessionid, p_username, p_nasipaddress,
    p_timestamp, p_acctstatustype, (p_acctinputoctets - Previous_Input_Octets), (p_acctoutputoctets - Previous_Output_Octets),
    (p_acctsessiontime - Previous_Session_Time));
END /
DELIMITER ;

