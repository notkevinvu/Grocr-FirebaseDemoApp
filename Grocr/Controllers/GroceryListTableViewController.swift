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

class GroceryListTableViewController: UITableViewController {

  // MARK: Constants
  let listToUsers = "ListToUsers"
  
  // MARK: Properties
  var items: [GroceryItem] = []
  var user: User!
  var userCountBarButtonItem: UIBarButtonItem!
    // tldr: this property allows for saving and syncing of data to the given location
    let ref = Database.database().reference(withPath: "grocery-items")
  
  
  override var preferredStatusBarStyle: UIStatusBarStyle {
    return .lightContent
  }
  
  // MARK: UIViewController Lifecycle
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    tableView.allowsMultipleSelectionDuringEditing = false
    
    userCountBarButtonItem = UIBarButtonItem(title: "1",
                                             style: .plain,
                                             target: self,
                                             action: #selector(userCountButtonDidTouch))
    userCountBarButtonItem.tintColor = UIColor.white
    navigationItem.leftBarButtonItem = userCountBarButtonItem
    
    user = User(uid: "FakeId", email: "hungry@person.food")
    
    addReferenceObserver()
  }
  
  // MARK: UITableView Delegate methods
  
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }
  
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "ItemCell", for: indexPath)
        let groceryItem = items[indexPath.row]

        cell.textLabel?.text = groceryItem.name
        cell.detailTextLabel?.text = groceryItem.addedByUser

        toggleCellCheckbox(cell, isCompleted: groceryItem.completed)

        return cell
    }
  
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
  
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {

        if editingStyle == .delete {
            /*
             removing an object via the object's reference's removeValue() method
             will trigger the listener that we defined in addObserverReference()
             to call its closure
             
             and since we set new items and reload the table view via the closure
             already, we do not need to do so here
             */
            let groceryItem = items[indexPath.row]
            groceryItem.ref?.removeValue()
        }
        
    }
  
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        // find the cell the user tapped via cellForRow(at:)
        guard let cell = tableView.cellForRow(at: indexPath) else { return }
        
        // get the corresponding groceryitem by using the index path row
        let groceryItem = items[indexPath.row]
        
        // grab the inverse of the grocery item's current 'completed' property
        let toggledCompletion = !groceryItem.completed
        
        // call toggleCellCheckbox to update the visual properties of the cell
        toggleCellCheckbox(cell, isCompleted: toggledCompletion)
        
        // use updateChildValues(_:), passing in a dictionary, to update firebase
        // this differs from setValue(_:) as this method applies updates, whereas
        // setValue replaces the entire value there
        groceryItem.ref?.updateChildValues([
            // pass in a dictionary with the updated completion value for the
            // 'completed' key
            "completed": toggledCompletion
        ])
        
    }
  
    func toggleCellCheckbox(_ cell: UITableViewCell, isCompleted: Bool) {
        if !isCompleted {
            cell.accessoryType = .none
            cell.textLabel?.textColor = .black
            cell.detailTextLabel?.textColor = .black
        } else {
            cell.accessoryType = .checkmark
            cell.textLabel?.textColor = .gray
            cell.detailTextLabel?.textColor = .gray
        }
    }
  
  // MARK: Add Item
  
    @IBAction func addButtonDidTouch(_ sender: AnyObject) {
        
        let alert = UIAlertController(title: "Grocery Item",
                                  message: "Add an Item",
                                  preferredStyle: .alert)

        let saveAction = UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            guard let self = self, let textField = alert.textFields?.first, let text = textField.text else { return }
            
            // create a new uncompleted GroceryItem using the current user's data
            let groceryItem = GroceryItem(name: text, addedByUser: self.user.email, completed: false)
            /*
             create a child ref - the key value (url) of this ref is the item's
             name in lowercase, so when users add duplicate items (even uppercased
             or mixed case), the db only saves the latest entry
            */
            let groceryItemRef = self.ref.child(text.lowercased())
            
            // save data to database. The setValue(_:) method expects a dictionary
            // the GroceryItem struct has a helper method to turn it into a dictionary
            groceryItemRef.setValue(groceryItem.toAnyObject())

            self.items.append(groceryItem)
            self.tableView.reloadData()
        }

        let cancelAction = UIAlertAction(title: "Cancel",
                                     style: .cancel)

        alert.addTextField()

        alert.addAction(saveAction)
        alert.addAction(cancelAction)

        present(alert, animated: true, completion: nil)
    }
  
  @objc func userCountButtonDidTouch() {
    performSegue(withIdentifier: listToUsers, sender: nil)
  }
    
    // MARK: Firebase methods
    
    // observing data changes and retrieving updated data
    private func addReferenceObserver() {
        
        // attach a listener to receive updates whenever the 'grocery-items'
        // endpoint is modified
        ref.observe(.value) { [weak self] (snapshot) in
            
            guard let self = self else { return }
            
            var newItems: [GroceryItem] = []
            
            // iterate through the data from the snapshot of the latest set of data
            // this contains the entire list of grocery items, not just updates
            for child in snapshot.children {
                
                // cast the child as a data snapshot and initialize the grocery item
                // with the snapshot (custom initializer method)
                if let snapshot = child as? DataSnapshot, let groceryItem = GroceryItem(snapshot: snapshot) {
                    newItems.append(groceryItem)
                }
            }
            
            self.items = newItems
            self.tableView.reloadData()
        }
    }
}
