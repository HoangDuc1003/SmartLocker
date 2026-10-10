package dao;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import util.Todo;

/** Roles and permissions: who may READ or WRITE which resource. */
public class PermissionDao {

    /** Every permission of a user as "RESOURCE:ACTION" strings, for example "USER:READ". */
    public Set<String> loadKeys(int userId) throws SQLException {
        throw Todo.of("PermissionDao.loadKeys: one query over UserRole, RolePerm and Permissions");
    }

    /** One row per role: role_id, role_name, rank_no, user_count, perm_count. */
    public List<Map<String, Object>> listRoles() throws SQLException {
        throw Todo.of("Roles LEFT JOIN counts of UserRole and RolePerm, ORDER BY rank_no");
    }

    /** Every permission with a flag telling if the role has it: {perm_id, resource, action, granted}. */
    public List<String[]> permissionGrid(int roleId) throws SQLException {
        throw Todo.of("Permissions LEFT JOIN RolePerm for this role, ORDER BY resource, action");
    }

    /** Replaces the permissions of a role. One transaction: DELETE the old rows, INSERT the ticked ones. */
    public void saveRolePerms(int roleId, int[] permIds) throws SQLException {
        throw Todo.of("DELETE FROM RolePerm WHERE role_id = ?, then batch INSERT, commit; rollback on error");
    }

    public String roleName(int roleId) throws SQLException {
        throw Todo.of("SELECT role_name FROM Roles WHERE role_id = ?");
    }
}
