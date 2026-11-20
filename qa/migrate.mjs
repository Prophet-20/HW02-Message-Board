import { collection, getDocs, runTransaction } from 'firebase/firestore';

// Run with a trusted maintenance context after reviewing legacy field mappings.
export async function migrate(db) {
  let changed = 0;
  for (const entry of (await getDocs(collection(db, 'messages'))).docs) {
    const migrated = await runTransaction(db, async tx => {
      const data = (await tx.get(entry.ref)).data();
      if (!data || (data.schemaVersion ?? 1) !== 1) return false;
      const {body, uid, name, sentAt, ...other} = data;
      if (typeof body !== 'string' || !uid || !sentAt) throw Error('Incomplete legacy record: ' + entry.id);
      tx.set(entry.ref, {...other, text: body, authorUid: uid, authorName: name || 'Member',
        createdAt: sentAt, editedAt: data.editedAt ?? null, schemaVersion: 2});
      return true;
    });
    if (migrated) changed++;
  }
  return changed;
}
