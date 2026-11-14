local db <const> = {}

---@param citizenid string
---@param job string
---@param amount integer
function db.logPayout(citizenid, job, amount)
    MySQL.insert('INSERT INTO job_payouts (citizenid, job, amount) VALUES (?, ?, ?)', { citizenid, job, amount })
end

---@return table<string, integer>
function db.paidToday()
    local rows <const> = MySQL.query.await([[
        SELECT job, SUM(amount) AS total FROM job_payouts
        WHERE created_at >= CURDATE()
        GROUP BY job ORDER BY job LIMIT 100
    ]])

    local totals <const> = {}

    for _, row in ipairs(rows or {}) do
        totals[row.job] = math.tointeger(row.total) or 0
    end

    return totals
end

---@return table<string, true>
function db.closedJobs()
    local rows <const> = MySQL.query.await('SELECT job FROM job_settings WHERE open = 0 ORDER BY job LIMIT 100')
    local closed <const> = {}

    for _, row in ipairs(rows or {}) do closed[row.job] = true end

    return closed
end

---@param job string
---@param open boolean
function db.setOpen(job, open)
    MySQL.insert('INSERT INTO job_settings (job, open) VALUES (?, ?) ON DUPLICATE KEY UPDATE open = VALUES(open)', {
        job,
        open and 1 or 0,
    })
end

return db
