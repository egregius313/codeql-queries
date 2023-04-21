/**
 * @name Python default password
 * @description Default password set in security sensitive database column
 * @kind problem
 * @problem.severity error
 * @id python/default-password-db
 * @precision high
 * @tags default-password
 *       python
 *       external/cwe/cwe-1393
 *       external/cwe/cwe-1392
 *       external/cwe/cwe-287
 *       external/cwe/cwe-284
 */

private import python

import github.DefaultPasswordDB

from DBColumn column, string varname, string dbname
where column.hasDefault()
and column.assignedToVariable() = varname
and column.getDbId() = dbname
and varname in ["password", "secret", "key", "token", "pwd"]
select column, "Default value in security-senstive database '" + dbname + "' $@ assigned to variable '" + varname + "'",
    column, "column"