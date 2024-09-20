import parsecnf as rd
import random

def clog2(x):
    """Ceiling of log2"""
    if x <= 0:
        raise ValueError("domain error")
    return (x-1).bit_length()

def convert_list_to_binary_string(mylist, bits_per_element):
    """
    Converts a list of ints or list of list of ints to a binary string
    Args:
    mylist (list): The list to convert
    bits_per_element (int): The number of bits to represent each element
    """
    if type(mylist[0]) == list:
        return '__'.join([convert_list_to_binary_string(sublist, bits_per_element) for sublist in mylist])
    elif type(mylist[0]) == int:
        return '_'.join([bin(element)[2:].zfill(bits_per_element) for element in mylist])
    else:
        raise ValueError(f"List must be a list of ints or a list of list of ints, is {type(mylist[0])}")


def create_clause_list(filename):
    """
    Creates a list of clauses based on a given CNF file in the format needed for the hardware solver.
    (L1 is 0, ~L1 is num_vars, L2 is 1, ~L2 is num_vars + 1, etc.)

    Args:
    filename (string): A problem .cnf file

    Returns:
    fixed_num_vars (int): The number of variables in the CNF file
    fixed_clause_list (list): A list of clauses, each clause being a list of literals
    """
    num_vars, clauses = rd.read_dimacs(filename)
    clause_list = []
    for clause in clauses:
        clause_list.append(clause[:3])
    fixed_clause_list = []

    fixed_num_vars = 2 ** clog2(num_vars)

    for clause in clause_list:
        fixed_clause = [(_-1 if _>0 else abs(_)-1 + fixed_num_vars) for _ in clause]
        fixed_clause_list.append(fixed_clause)
    return fixed_num_vars, fixed_clause_list    

def generate_clause_membership_list(num_vars, clause_list, is_exclusive = True):
    """
    Generates a list which holds the literal address along with a list of the addresses of the 
    literals in for each of the clauses that literal is in. 
    When is_exclusive is True, the clause list will not contain the address of the literal itself.

    Args:
    num_vars (int): The number of variables in the problem (needs to be a power of two for the hardware solver)
    clause_list (list): A list of clauses, each clause being a list of literals
    is_exclusive (bool): If True, the clause list will not contain the address of the literal itself

    Returns:
    literal_clause_membership_list (list): A list of literals and membership, each element being a 
    list of two elements: the literal and a list of the literals in the clauses that literal is in

    Example of output:
    [[1, [[2, 3], [4, 5]]], [2, [[1, 3], [4, 5]]], ...]
    """
    literal_clause_membership_list = [[_, []] for _ in range(2 * num_vars)]

    for clause in clause_list:
        for literal in clause:
            if(is_exclusive):
                use_clause = [_ for _ in clause if _ != literal]
            else:
                use_clause = [_ for _ in clause]
            literal_clause_membership_list[literal][1].append(use_clause)
    return literal_clause_membership_list


def generate_att_and_ct(literal_clause_membership_list):
    """
    Generates the Address Translation Table and Clause Table based on the literal clause membership 
    list by running a modified version of the packing algorithm in packing.py 

    Args:
    literal_clause_membership_list (list): A list of literals and membership, each element being a
    list of two elements: the literal and a list of the literals in the clauses that literal is in

    Returns:
    att (list): The Address Translation Table entries which are 31 bits wide. Indices under num_vars
    represent the un-negated literals, and indices over num_vars represent the negated literals.
    The first 11 bits are  the index of the clause table entry for the literal, and the next 20 bits
    are the mask for the literal.

    ct (list): The Clause Table entries which are 12*2*20 bits wide. Each entry is a list of 20 
    groups of 2 literals corresonding to the other two literals in each of the clauses that the  
    literal used to index the att is in.

    The returns are lists in the format necessary for the .mem files for the hardware solver.
    """
    # num_literals = len(literal_clause_membership_list)
    literal_membership_count = [len(literal[1]) for literal in literal_clause_membership_list]
    literal_membership_count_sorted = sorted(enumerate(literal_membership_count), key=lambda x: x[1])

    att = [0 for _ in range(4096)]
    ct = [[] for _ in range(2048)]

    ct_address = 0

    while len(literal_membership_count_sorted) > 1:
        small_address, small_count = literal_membership_count_sorted.pop(0)
        small_membership = literal_clause_membership_list[small_address][1]

        large_address, large_count = literal_membership_count_sorted.pop()
        large_membership = literal_clause_membership_list[large_address][1]

        combined_count = small_count + large_count
        filler_membership = [[0,0] for _ in range(20 - combined_count)]

        if combined_count > 20:
            raise ValueError(f"Literal {large_address} is in {large_count} clauses, and literal {small_address} is in {small_count} clauses. Their sum exceeds the maximum of 20.")
        
        current_ct_entry = [large_membership + filler_membership + small_membership]
        ct[ct_address] = convert_list_to_binary_string(current_ct_entry, 12)
        # ct[ct_address] = current_ct_entry
        # if(ct_address == 0):
        #     print(current_ct_entry)

        large_mask = '1' * large_count + '0' * (20 - combined_count) + '0' * small_count
        small_mask = '0' * large_count + '0' * (20 - combined_count) + '1' * small_count

        ct_address_binary = bin(ct_address)[2:].zfill(11)

        att[small_address] = ct_address_binary + '_' + small_mask
        att[large_address] = ct_address_binary + '_' + large_mask

        ct_address += 1

    return att, ct

def generate_vt_and_ucb(variable_table_size, clauses, num_tries):
    """
    Generates num_tries random assignments for the variable table and an unsat clause buffers based
    on that assignment. It returns the variable table and unsat clause buffer that have the minimum 
    number of unsatisfied clauses

    Args:
    variable_table_size (int): The number of variables in the problem (power of 2)
    clauses (list): A list of clauses, each clause being a list of literals
    num_tries (int): The number of random assignments to try
    Returns:
    vt (list): The variable table with random assignments
    ucb (list): A list of unsatisfied clauses for the generated variable assignment
    """

    best_vt = [0 for _ in range(variable_table_size)]
    best_ucb = [0 for _ in range(len(clauses))]
    
    for _ in range(num_tries):
        candidate_vt = [random.randint(0, 1) for _ in range(variable_table_size)]
        candidate_ucb = []
        for clause in clauses:
            is_sat = False
            for literal in clause:
                if literal < variable_table_size:
                    if candidate_vt[literal] == 1:
                        is_sat = True
                        break
                else: # negated literal
                    if candidate_vt[literal - variable_table_size] == 0:
                        is_sat = True
                        break
            if not is_sat:
                candidate_ucb.append(clause)

        if len(candidate_ucb) < len(best_ucb) or not best_ucb:
            best_vt = candidate_vt.copy()
            best_ucb = candidate_ucb.copy()
    
    ucb = [convert_list_to_binary_string(entry, 12) for entry in best_ucb]


    return best_vt, ucb

def write_list_to_file(mylist, filename):
    with open(filename, 'w') as file:
        for element in mylist:
            file.write(str(element) + '\n')            

def write_to_memb_file(uint32_list, filename, bits_per_line=32):
    """
    Write uint32 list to a .memh file.
    Args:
    uint32_list (list): The uint32 list to write.
    filename (str): The filename to write to.
    bits_per_line (int): The number of bits per line.
    """
    with open(filename, 'w') as file:
        for value in uint32_list:
            file.write(bin(value)[2:].zfill(bits_per_line) + '\n')
    
    print(f"Written to {filename}")
