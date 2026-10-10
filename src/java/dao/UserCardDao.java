package dao;

import java.sql.CallableStatement;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Types;
import java.util.ArrayList;
import java.util.List;
import model.UserCard;
import util.Todo;

/** RFID cards. Reporting and replacing a card go through stored procedures so they are audited. */
public class UserCardDao {

    /** Case 3: every card that must not open a door. The heartbeat reply carries this list to the device. */
    public List<String> blockedUids() throws SQLException {
        throw Todo.of("UserCardDao.blockedUids: SELECT card_uid FROM UserCard WHERE status <> 'ACTIVE'");
    }

    /** The owner reports the card lost. The procedure refuses another user's card (error 50020). */
    public void reportLost(int cardId, int actorId) throws SQLException {
        throw Todo.of("UserCardDao.reportLost: {call UserCard_ReportLost(?, ?)}; the THROW text of the procedure is the SQLException message");
    }

    /** An operator issues a new card in place of a lost one. Returns the new card_id. */
    public int replace(int oldCardId, String newUid, int actorId) throws SQLException {
        throw Todo.of("UserCardDao.replace: {call UserCard_Replace(?, ?, ?, ?)} with an OUTPUT parameter");
    }

    /** One page for the operator, keyword matches card uid or username. */
    public List<UserCard> search(String keyword, String status, int page, int size) throws SQLException {
        throw Todo.of("UserCard JOIN Users, optional keyword and status filters, OFFSET/FETCH");
    }

    public int count(String keyword, String status) throws SQLException {
        throw Todo.of("SELECT COUNT(*) with the same filters");
    }

    /** The cards of one user, newest first: the My cards page. */
    public List<UserCard> listByUser(int userId) throws SQLException {
        throw Todo.of("SELECT ... WHERE user_id = ? ORDER BY issued_at DESC");
    }

    public UserCard findById(int cardId) throws SQLException {
        throw Todo.of("one card by id");
    }

    /** Issues a card to a user. A uid already in the table is SQL error 2627. */
    public int insert(UserCard c) throws SQLException {
        throw Todo.of("INSERT card_uid, user_id with RETURN_GENERATED_KEYS");
    }

    /** An operator blocks or unblocks a card: ACTIVE or BLOCKED. */
    public boolean setStatus(int cardId, String status) throws SQLException {
        throw Todo.of("UPDATE UserCard SET status = ?");
    }
}
