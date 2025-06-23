# Tests for RPCL3


(75) : ==> Call to nonexistent function.
Specifically: Join(" AND ", filters) in this part:
whereClause .= " AND " . Join(" AND ", filters)

; Helper function for joining array elements - for AHK v1
Join(sep, ByRef arr) {
out := ""
for index, val in arr
out .= (index > 1 ? sep : "") . val
return out
}
