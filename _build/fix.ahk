Great! The debug information shows that the file is being read correctly (77,970 bytes) and the SQL statement is properly formatted. Since you're seeing the debug message but still getting the "Failed to save icon to database" error, the issue is specifically with the StoreBLOB() method call or the BLOB array format.

Here are the most likely fixes to try:

1. Fix the BLOB Array Format
Different SQLiteDB wrappers expect different formats. Try these variations:

Option A - Simple array:

; Instead of:
blobArray := []
blobArray[1] := {Addr: &iconData, Size: bytesRead}

; Try:
blobArray := [iconData]  ; Just pass the data directly
Option B - Different property names:

blobArray := [{Data: iconData, Length: bytesRead}]
; or
blobArray := [{Blob: iconData, Size: bytesRead}]
; or
blobArray := [{Buffer: &iconData, Length: bytesRead}]
2. Check Return Value and Error Details
Add more specific debugging:

result := db.StoreBLOB(updateSql, blobArray)
MsgBox, Debug Result, StoreBLOB returned: %result%

if (!result) {
    errMsg := db.ErrorMsg
    errCode := db.ErrorCode
    lastError := db.LastError  ; If available
    MsgBox, Debug Error, Result: %result%`nCode: %errCode%`nMsg: %errMsg%`nLast: %lastError%
}
3. Try Using Regular Exec with Manual BLOB Binding
Some SQLiteDB wrappers work better with direct execution:

; Try this instead of StoreBLOB:
if (db.Exec(updateSql, iconData)) {
    ; Success
} else {
    ; Error
}
4. Alternative: Use Prepared Statement Approach
; Prepare statement first
stmt := db.Prepare(updateSql)
if (stmt) {
    stmt.Bind(1, iconData)  ; Bind parameter 1
    result := stmt.Step()
    stmt.Finalize()

    if (result) {
        ; Success
    }
}
5. Most Likely Solution
Based on typical SQLiteDB wrappers for AutoHotkey, try this exact format:

; Create the BLOB array in the expected format
VarSetCapacity(iconData, fileLength)
bytesRead := file.RawRead(iconData, fileLength)
file.Close()

; Create BLOB parameter - try this exact format:
blobParams := []
blobParams.Push({Addr: &iconData, Size: bytesRead, Type: "blob"})

; Or even simpler:
blobParams := [{Addr: &iconData, Size: bytesRead}]

result := db.StoreBLOB(updateSql, blobParams)
6. Check Your SQLiteDB.ahk Version
The issue might be with the specific SQLiteDB wrapper you're using. Can you check:

What version/source of SQLiteDB.ahk you're using?
Look for any example BLOB usage in the SQLiteDB.ahk file itself
The most common issue is that StoreBLOB() expects a different array format than what you're providing. Try the simpler array formats first, as many wrappers just need the raw data without the address/size wrapper.

Which of these approaches works, or do you get any different error messages?

