private import python
private import semmle.python.dataflow.new.DataFlow
private import semmle.python.dataflow.new.TaintTracking
private import semmle.python.ApiGraphs
private import semmle.python.dataflow.new.RemoteFlowSources


class
User extends ClassDef {
    Class class_;
    string name;
    Expr base;
    Value ref;
    string password_variable;

    User() {
        this.getDefinedClass() = class_
        and class_.getName() = name
        and class_.getABase() = base
        and base.pointsTo(ref)
        and (
            ref.getName() = "UserMixin"
            and password_variable = "password"
            or
            (
                ref.getName() = "Model"
                and exists(class_.getInitMethod().getArgByName(password_variable))
                and password_variable.regexpMatch("^(?:password|pass|pwd|passwd)$")
            )
        )
    }
    predicate
    usesUserMixin() {
        ref.getName() = "UserMixin"
    }

    string
    getPasswordVariable() {
        result = password_variable
    }

    string
    getName() {
        result = name
    }

    Function
    getInit() {
        result = class_.getInitMethod()
    }

    predicate
    hasInit() {
        exists(class_.getInitMethod())
    }

    predicate
    inInit(DataFlow::Node node) {
        this.getInit().getBody().contains(node.asExpr())
    }

    // TODO: account for named arguments? Can that we used for this?
    predicate
    isPasswordArg(DataFlow::Node node) {
        exists (Variable var |
            node.asExpr() = this.getInit().getArg(2)
            and node.asExpr() = var.getAnAccess()
        )
    }

    predicate
    passwordAssignedFrom(DataFlow::Node node) {
        this.inInit(node) and
        exists(SelfPasswordAttribute password |
            this.inInit(password)
            and password.assignedFrom(node)
        )
    }

    predicate
    hasSecureInit() {
        this.hasInit() and
        not exists(InsecureHashTrackingConfiguration conf, DataFlow::Node source, DataFlow::Node sink |
            this.inInit(sink)
            and this.isPasswordArg(source)
            and conf.hasFlow(source, sink)
        )
    }

    predicate
    usedSecurely() {
        not exists(InsecureTaintTrackingConfiguration conf, DataFlow::Node source, DataFlow::Node sink |
            conf.hasFlow(source, sink)
            and sink.(PasswordArg).getUser() = this
        )
    }

    predicate
    isSecure() {
        this.hasSecureInit()
        or this.usedSecurely()
    }
}

class
InsecureTaintTrackingConfiguration extends TaintTracking::Configuration {
    // is the password used in the init of the User protected by a secure hash?
    InsecureTaintTrackingConfiguration() { this = "InsecureTaintTrackingConfiguration" }

    override
    predicate
    isSource(DataFlow::Node source) {
        source instanceof RemoteFlowSource
    }

    override
    predicate
    isSink(DataFlow::Node sink) {
        sink instanceof PasswordArg
    }

    override
    predicate
    isSanitizer(DataFlow::Node node) {
        node instanceof HashSanitizer
    }
}

class
InsecureHashTrackingConfiguration extends TaintTracking::Configuration {
    User user;

    // does the body of the init of the User hash the password?
    InsecureHashTrackingConfiguration() { this = "InsecureHashTrackingConfiguration" }

    override
    predicate
    isSource(DataFlow::Node source) {
        user.isPasswordArg(source)
    }

    override
    predicate
    isSink(DataFlow::Node sink) {
        user.passwordAssignedFrom(sink)
        and not sink instanceof HashSanitizer
    }

    override
    predicate
    isSanitizer(DataFlow::Node node) {
        node instanceof HashSanitizer
    }
}

// assigment to self.password
class
SelfPasswordAttribute extends DataFlow::Node {
    Variable self;
    Name self_access;
    Attribute password;
    string password_attr_name;

    SelfPasswordAttribute() {
        this.asExpr() = password
        and password_attr_name.regexpMatch("^(?:password|pass|pwd|passwd)$")
        and password.getObject(password_attr_name) = self_access
        and self.isSelf()
        and self_access = self.getAnAccess()
    }

    predicate
    assignedFrom(DataFlow::Node node) {
        exists(AssignStmt assign|
            assign.getValue().getAChildNode*() = node.asExpr()
            and assign.getATarget() = this.asExpr()
        )
    }
}

class
PasswordArg extends DataFlow::Node {
    User user;

    PasswordArg() {
        exists(Call init |
            init.getArg(1) = this.asExpr()
            and user.getName() = init.getFunc().(Name).getId()
        )
    }

    User
    getUser() {
        result = user
    }
}

class
HashSanitizer extends DataFlow::Node {
    Call hash;
    API::Node member;

    HashSanitizer() {
        (
            API::moduleImport("flask_security").getMember("hash_password") = member
            or
            API::moduleImport("flask_security").getMember("utils").getMember("hash_password") = member
            or
            API::moduleImport("werkzeug").getMember("security").getMember("generate_password_hash") = member
            or
            API::moduleImport("werkzeug").getMember("generate_password_hash") = member
            or
            API::moduleImport("flask_bcrypt").getMember("Bcrypt").getMember("generate_password_hash") = member
            or
            API::moduleImport("flask_argon2").getMember("Argon2").getMember("generate_password_hash") = member
        )
        and member.getACall().asExpr() = hash
        and hash.getArg(0) = this.asExpr()
    }
}