/**
 * @name Command Injection into Runtime.exec() with dangerous command
 * @description High sensitvity and precision version of java/command-line-injection, designed to find more cases of command injection in rare cases that the default query does not find
 * @kind path-problem
 * @problem.severity error
 * @security-severity 6.1
 * @precision high
 * @id java/command-line-injection-extra
 * @tags security
 *       external/cwe/cwe-078
 */


import DataFlow::PathGraph
import github.CommandInjectionRuntimeExec


from DataFlow::PathNode source, DataFlow::PathNode sink, ExecTaintConfiguration2 conf, MethodAccess call, int index, DataFlow::Node sourceCmd, DataFlow::Node sinkCmd, ExecTaintConfiguration confCmd
where call.getMethod() instanceof RuntimeExecMethod
// this is a command-accepting call to exec, e.g. exec("/bin/sh", ...)
and (
    confCmd.hasFlow(sourceCmd, sinkCmd)
    and sinkCmd.asExpr() = call.getArgument(0)
)
// it is tainted by untrusted user input
and (
    conf.hasFlow(source.getNode(), sink.getNode())
    and sink.getNode().asExpr() = call.getArgument(index)
)
select sink, source, sink, "Call to dangerous java.lang.Runtime.exec() with command '$@' with arg from untrusted input '$@'",
    sourceCmd, sourceCmd.toString(),
    source.getNode(), source.toString()
