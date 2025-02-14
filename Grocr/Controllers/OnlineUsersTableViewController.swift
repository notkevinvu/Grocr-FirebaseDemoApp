/// Copyright (c) 2018 Razeware LLC
///
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
///
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
///
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

import UIKit
import Firebase

class OnlineUsersTableViewController: UITableViewController {
  
    // MARK: Constants
    let userCell = "UserCell"

    // MARK: Properties
    var currentUsers: [String] = []
    let usersRef = Database.database().reference(withPath: "online")
  
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
  
    // MARK: UIViewController Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        observeCurrentUsersReference()
    }
    
    // MARK: Helper methods
    
    private func observeCurrentUsersReference() {
        // update table view with the added child/value
        usersRef.observe(.childAdded) { [weak self] (snap) in
            guard let self = self else { return }
            
            guard let email = snap.value as? String else { return }
            self.currentUsers.append(email)
            
            // inserting row at the correct index in the table view
            let row = self.currentUsers.count - 1
            let indexPath = IndexPath(row: row, section: 0)
            // only renders items as they are added with an animation rather than
            // reloading the entire list
            self.tableView.insertRows(at: [indexPath], with: .top)
        }
        
        usersRef.observe(.childRemoved) { [weak self] (snap) in
            guard
                let self = self,
                let emailToFind = snap.value as? String
                else {
                    return
            }
            
            for (index, email) in self.currentUsers.enumerated() {
                if email == emailToFind {
                    let indexPath = IndexPath(row: index, section: 0)
                    self.currentUsers.remove(at: index)
                    self.tableView.deleteRows(at: [indexPath], with: .fade)
                }
            }
        }
    }
    
    // MARK: UITableView Delegate methods
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return currentUsers.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: userCell, for: indexPath)
        let onlineUserEmail = currentUsers[indexPath.row]
        cell.textLabel?.text = onlineUserEmail
        return cell
    }
    
    // MARK: Actions
    
    @IBAction func signoutButtonPressed(_ sender: AnyObject) {
        
        // get current user and create a reference based on its online user uid
        let user = Auth.auth().currentUser!
        let onlineRef = Database.database().reference(withPath: "online/\(user.uid)")
        
        // call removeValue on that reference to remove the user from the online path
        // - firebase adds the user to 'online' upon sign in but does not remove
        // on sign out
        onlineRef.removeValue { (error, dbref) in
            
            // error handling
            if let error = error {
                print("Removing online failed: \(error).")
                return
            }
            
            // call the signOut() method, which removes the current user's
            // credentials form the keychain
            do {
                try Auth.auth().signOut()
                self.dismiss(animated: true, completion: nil)
            } catch let error {
                print("Auth sign out failed: \(error)")
            }
        }
        
    }
}
