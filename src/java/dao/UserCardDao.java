package dao;

import java.sql.CallableStatement;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.sql.Types;
import java.util.ArrayList;
import java.util.List;
import model.UserCard;

/** RFID cards. Reporting and replacing a card go through stored procedures so they are audited. */
public class UserCardDao {

    private static final String SELECT = "SELECT c.card_id, c.card_uid, c.user_id, u.username, c.status, c.issued_at, c.lost_at "
            + "FROM UserCard c JOIN Users u ON u.user_id = c.user_id";

    private static UserCard map(ResultSet rs) throws SQLException {
        UserCard c = new UserCard();
        c.setCardId(rs.getInt("card_id"));
        c.setCardUid(rs.getString("card_uid"));
        c.setUserId(rs.getInt("user_id"));
        c.setUsername(rs.getString("username"));
        c.setStatus(rs.getString("status"));
        c.setIssuedAt(rs.getTimestamp("issued_at"));
        c.setLostAt(rs.getTimestamp("lost_at"));
        return c;
    }

    private static String where(String keyword, String status, List<Object> params) {
        StringBuilder sb = new StringBuilder(" WHERE 1 = 1");
        if (keyword != null && !keyword.trim().isEmpty()) {
            sb.append(" AND (c.card_uid LIKE ? OR u.username LIKE ?)");
            String k = "%" + keyword.trim() + "%";
            params.add(k);
            params.add(k);
        }
        if (status != null && !status.trim().isEmpty()) {
            sb.append(" AND c.status = ?");
            params.add(status.trim());
        }
        return sb.toString();
    }

    private static void bind(PreparedStatement ps, List<Object> params) throws SQLException {
        for (int i = 0; i < params.size(); i++) {
            ps.setObject(i + 1, params.get(i));
        }
    }

    /** Case 3: every card that must not open a door. The heartbeat reply carries this list to the device. */
    public List<String> blockedUids() throws SQLException {
        List<String> list = new ArrayList<>();
        try (Connection conn = DbContext.getConnection();
             PreparedStatement ps = conn.prepareStatement("SELECT card_uid FROM UserCard WHERE status <> 'ACTIVE'");
             ResultSet rs = ps.executeQuery()) {
            while (rs.next()) {
                list.add(rs.getString(1));
            }
        }
        return list;
    }

    /** The owner reports the card lost. The procedure refuses another user's card (error 50020). */
    public void reportLost(int cardId, int actorId) throws SQLException {
        try (Connection conn = DbContext.getConnection();
             CallableStatement cs = conn.prepareCall("{call UserCard_ReportLost(?, ?)}")) {
            cs.setInt(1, cardId);
            cs.setInt(2, actorId);
            cs.execute();
        }
    }

    /** An operator issues a new card in place of a lost one. Returns the new card_id. */
    public int replace(int oldCardId, String newUid, int actorId) throws SQLException {
        try (Connection conn = DbContext.getConnection();
             CallableStatement cs = conn.prepareCall("{call UserCard_Replace(?, ?, ?, ?)}")) {
            cs.setInt(1, oldCardId);
            cs.setString(2, newUid);
            cs.setInt(3, actorId);
            cs.registerOutParameter(4, Types.INTEGER);
            cs.execute();
            return cs.getInt(4);
        }
    }

    /** One page for the operator, keyword matches card uid or username. */
    public List<UserCard> search(String keyword, String status, int page, int size) throws SQLException {
        List<Object> params = new ArrayList<>();
        String sql = SELECT + where(keyword, status, params)
                + " ORDER BY c.card_id DESC OFFSET ? ROWS FETCH NEXT ? ROWS ONLY";
        params.add((page - 1) * size);
        params.add(size);
        List<UserCard> list = new ArrayList<>();
        try (Connection conn = DbContext.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            bind(ps, params);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    list.add(map(rs));
                }
            }
        }
        return list;
    }

    public int count(String keyword, String status) throws SQLException {
        List<Object> params = new ArrayList<>();
        String sql = "SELECT COUNT(*) FROM UserCard c JOIN Users u ON u.user_id = c.user_id" + where(keyword, status, params);
        try (Connection conn = DbContext.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            bind(ps, params);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() ? rs.getInt(1) : 0;
            }
        }
    }

    /** The cards of one user, newest first: the My cards page. */
    public List<UserCard> listByUser(int userId) throws SQLException {
        String sql = SELECT + " WHERE c.user_id = ? ORDER BY c.issued_at DESC";
        List<UserCard> list = new ArrayList<>();
        try (Connection conn = DbContext.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, userId);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    list.add(map(rs));
                }
            }
        }
        return list;
    }

    public UserCard findById(int cardId) throws SQLException {
        String sql = SELECT + " WHERE c.card_id = ?";
        try (Connection conn = DbContext.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, cardId);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() ? map(rs) : null;
            }
        }
    }

    /** Issues a card to a user. A uid already in the table is SQL error 2627. */
    public int insert(UserCard c) throws SQLException {
        String sql = "INSERT INTO UserCard (card_uid, user_id, status) VALUES (?, ?, ?)";
        try (Connection conn = DbContext.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql, Statement.RETURN_GENERATED_KEYS)) {
            ps.setString(1, c.getCardUid());
            ps.setInt(2, c.getUserId());
            ps.setString(3, c.getStatus() != null ? c.getStatus() : "ACTIVE");
            ps.executeUpdate();
            try (ResultSet keys = ps.getGeneratedKeys()) {
                return keys.next() ? keys.getInt(1) : -1;
            }
        }
    }

    /** An operator blocks or unblocks a card: ACTIVE or BLOCKED. */
    public boolean setStatus(int cardId, String status) throws SQLException {
        String sql = "UPDATE UserCard SET status = ? WHERE card_id = ?";
        try (Connection conn = DbContext.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, status);
            ps.setInt(2, cardId);
            return ps.executeUpdate() == 1;
        }
    }
}
